Emulator :: struct {
  ram: [65536] u8;
  ip: u16;
  regs: [Register.DI+1] [2]u8;
}

Register :: enum u8 {
  AX; CX; DX; BX; SP; BP; SI; DI;
}

emulate :: (bytes: [] u8) {
  emulator := New(Emulator);
  defer free(emulator);

  slice_copy(head(emulator.ram, bytes.count), bytes);
  print("%", emulator.ram);

  running := true;
  while running {
    temp := tail(emulator.ram, emulator.ip);
    decode(disassemble_one, *temp, temp[0], temp[1]);

    last_ip := emulator.ip;

    decode(step_one, emulator, emulator.ram[emulator.ip], emulator.ram[emulator.ip+1]);

    print(
      "ax = %, bx = %, cx = %, dx = %, sp = %, ip = %\n",
      get_integer_value(emulator.regs[Register.AX], word = true, signed = false),
      get_integer_value(emulator.regs[Register.BX], word = true, signed = false),
      get_integer_value(emulator.regs[Register.CX], word = true, signed = false),
      get_integer_value(emulator.regs[Register.DX], word = true, signed = false),
      get_integer_value(emulator.regs[Register.SP], word = true, signed = false),
      emulator.ip,
    );

    print(
      "[1000] = %\n[1002] = %\n[1004] = %\n[1006] = %\n",
      read_ram(emulator, 1000, word = true, signed = false),
      read_ram(emulator, 1002, word = true, signed = false),
      read_ram(emulator, 1004, word = true, signed = false),
      read_ram(emulator, 1006, word = true, signed = false),
    );

    if emulator.ip >= bytes.count  running = false;
    if last_ip == emulator.ip {
      log("Bingus");
      break;
    }
  }
}

step_one :: (info: DecodeInfo, using emulator: *Emulator) {
  using info;

  if #complete info.op == {
    case .NO_OP;

    case .MOV_RM2R;
      ip += 2;
      ip_shift, ea_loc := eval_effective_address_or_reg(emulator, ip, mod, r_m, word = w);
      reg_loc := eval_reg(emulator, reg, w = w);
      ip += ip_shift;

      if d {
        write_to_location(reg_loc, ea_loc);
      }
      else {
        write_to_location(ea_loc, reg_loc);
      }

    case .MOV_I2RM;
      ip += 2;
      ip_shift, ea_loc := eval_effective_address_or_reg(emulator, ip, mod, r_m, word = w);
      ip += ip_shift;
      write_to_location(ea_loc, cast(u16) read_immediate(emulator, word = w, signed = false));
      ip += 1 + (cast(u16)w);

    case .MOV_I2R;
      ip += 1;
      write_to_location(eval_reg(emulator, reg, w), cast(u16) read_immediate(emulator, word = w, signed = false));
      ip += 1 + (cast(u16)w);

    case .MOV_M2A;
      ip += 1;
      ram_loc := array_view(ram, read_immediate(emulator, word = w, signed = false), 1 + cast(u16)w);
      ip += 1 + (cast(u16)w);
      write_to_location(eval_reg(emulator, 0 /* .AX */, w), ram_loc);

    case .MOV_A2M;
      ip += 1;
      ram_loc := array_view(ram, read_immediate(emulator, word = w, signed = false), 1 + cast(u16)w);
      ip += 1 + cast(u16)w;
      write_to_location(ram_loc, eval_reg(emulator, 0 /* .AX */, w));

    case .MOV_RM2S;

    case .MOV_S2RM;

    case .BIN_OP_R;
      ip += 2;
      ip_shift, ea_loc := eval_effective_address_or_reg(emulator, ip, mod = mod, r_m = r_m, word = w);
      ip += ip_shift;
      reg_loc := eval_reg(emulator, reg, w);

      if d {
        apply_op(bin_op, reg_loc, xx get_integer_value(ea_loc, word = w, signed = false));
      }
      else {
        apply_op(bin_op, ea_loc,  xx get_integer_value(reg_loc, word = w, signed = false));
      }

    case .BIN_OP_I;
      imm_size := 1 + (cast(u16) (!s && w));

      ip += 2;
      ip_shift, ea_loc := eval_effective_address_or_reg(emulator, ip, mod = mod, r_m = r_m, word = w);
      ip += ip_shift;
      imm := read_immediate(emulator, word = w, signed = false);
      ip += 1 + cast(u16)w;

      apply_op(bin_op, ea_loc, imm);

    case .BIN_OP_A;
      ip += 1;
      reg_loc := eval_reg(emulator, 0 /* .AX */, w);
      imm := read_immediate(emulator, word = w, signed = false);
      ip += 1 + cast(u16)w;
      apply_op(bin_op, reg_loc, imm);
  }
}

head :: inline (arr: [] $T, length: s64) -> [] T {
  result: [] T = ---;

  assert(length >= 0 && length <= arr.count);
  result.data  = arr.data;
  result.count = length;

  return result;
}

tail :: inline (arr: [] $T, skip: s64) -> [] T {
  result: [] T = ---;

  assert(skip >= 0 && skip <= arr.count);
  result.data  = arr.data  + skip;
  result.count = arr.count - skip;

  return result;
}

slice_copy :: (dest: [] $T, src: [] T) {
  assert(dest.count == src.count);
  memcpy(dest.data, src.data, dest.count * size_of(T));
}

Location :: [] u8;

eval_effective_address_or_reg :: (emulator: Emulator, address: u16, mod: Mov_Mode, r_m: u8, word: bool) -> (ip_shift: u16, location: Location) {
  if #complete mod == {
    case .MEM_MODE_NO_DISP; #through;
    case .MEM_MODE_8_DISP;  #through;
    case .MEM_MODE_16_DISP;
      temp_ip_shift, temp_location := eval_effective_address(emulator, address, mod = mod, r_m = r_m, word = word);
      return temp_ip_shift, temp_location;

    case .REG_MODE;
      return 0, eval_reg(emulator, r_m, word);
  }
}

eval_effective_address :: (using emulator: Emulator, address: u16, mod: Mov_Mode, r_m: u8, word: bool) -> (ip_shift: u16, location: Location) {
  direct := mod == .MEM_MODE_NO_DISP && r_m == 0b110;

  offset: int;
  formatted_offset: FormatInt;
  num_digits: int;
  add_or_sub: string;

  data_size := ifx word then "word" else "byte";

  ip_shift: u16 = 0;
  location: Location;

  if mod != .MEM_MODE_NO_DISP || direct {
    disp_16 := mod == .MEM_MODE_16_DISP || direct;
    offset = read_ram(emulator, address, word = disp_16, signed = !direct);

    ip_shift = 1 + (cast(u16)disp_16);
  }

  if direct {
    location = array_view(emulator.ram, offset, 1 + (cast(u16)word));
  }
  else {
    address_to_read: u16;

    get_u16 :: (arr) => cast(u16) get_integer_value(arr, word = true, signed = false);

    if r_m == { // @Cleanup enum for this?
      case 0;
        address_to_read = get_u16(regs[Register.BX]) + get_u16(regs[Register.SI]);
      case 1;
        address_to_read = get_u16(regs[Register.BX]) + get_u16(regs[Register.DI]);
      case 2;
        address_to_read = get_u16(regs[Register.BP]) + get_u16(regs[Register.SI]);
      case 3;
        address_to_read = get_u16(regs[Register.BP]) + get_u16(regs[Register.DI]);
      case 4;
        address_to_read = get_u16(regs[Register.SI]);
      case 5;
        address_to_read = get_u16(regs[Register.DI]);
      case 6;
        address_to_read = get_u16(regs[Register.BP]);
      case 7;
        address_to_read = get_u16(regs[Register.BX]);
    }

    if mod != .MEM_MODE_NO_DISP {
      address_to_read += xx offset;
    }

    location = array_view(emulator.ram, address_to_read, 1 + (cast(u16)word));
  }

  return ip_shift, location;
}

eval_reg :: (using emulator: Emulator, reg: int, w: bool) -> Location {
  to_reg_index : [2][] Register : .[
    /* w == 0 */ .[.AX, .CX, .DX, .BX, .AX, .CX, .DX, .BX],
    /* w == 1 */ .[.AX, .CX, .DX, .BX, .SP, .BP, .SI, .DI],
  ];

  get_high  := cast(u16) (!w && reg >= 4);
  num_bytes := 1 + (cast(u16)w);
  return array_view(regs[to_reg_index[cast(int)w][reg]], get_high, num_bytes);
}

read_ram :: (using emulator: Emulator, address: u16, word: bool, signed: bool) -> s32 {
  return xx get_integer_value(tail(ram, address), word = word, signed = signed);
}

read_ram :: (using emulator: Emulator, location: Location, signed: bool) -> s32 {
  return xx get_integer_value(location, word = location.count == 2, signed = signed);
}

read_immediate :: (using emulator: Emulator, word: bool, signed: bool) -> s32 {
  return read_ram(emulator, ip, word, signed);
}

write_to_location :: (location: Location, value: u16) {
  location[0] = xx value & 0xFF;
  if location.count == 2 {
    location[1] = xx value >> 8;
  }
}

write_to_location :: (dest: Location, src: Location) {
  write_to_location(dest, cast(u16) get_integer_value(src, word = src.count == 2, signed = false));
}

apply_op :: (op: Binary_Op, dest: Location, value: s32) {
  dest_val := get_integer_value(dest, word = dest.count == 2, signed = false);

  if #complete op == {
    case .ADD;
      dest_val += value;
    case .ADC;
      dest_val += value;
    case .SBB;
      dest_val -= value;
    case .SUB;
      dest_val -= value;
    case .CMP;
  }

  write_to_location(dest, cast,no_check(u16) dest_val);
}