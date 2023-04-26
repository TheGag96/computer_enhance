#load "window.jai";

#import "Debug";

DEBUG_LOG := false;

Emulator :: struct {
  ram: [65536] u8;
  program_end: u16;
  ip: u16;
  regs: [Register.DI+1] [2]u8;
  zf, pf, sf, of, cf, af, df, tf: bool;
}

Register :: enum u8 {
  AX; CX; DX; BX; SP; BP; SI; DI;
}

OUTPUT_IMAGE_ON_EXIT :: false;
IMAGE_ADDDRESS       :: 64*4;
IMAGE_SIZE           :: 64*64*4;

INPUT_REGISTER       :: 0xFFFE;

emulate :: (bytes: [] u8) {
  emulator := New(Emulator);
  defer free(emulator);

  emu_window: Emulator_Window;
  window_started := false;

  emulator_load_program_to_ram(emulator, bytes);

  running := true;
  while running {
    emulate_result := emulator_run(emulator);

    if emulate_result.interrupted {
      if emulate_result.interrupt_type == {
        // Interrput 0x0: window resize
        case 0;
          window_width, window_height := read_reg(emulator, .AX, word = true, signed = false),
                                         read_reg(emulator, .BX, word = true, signed = false);

          if window_started {
            // @TODO
            // emulator_window_resize(emu_window, xx window_width, xx window_height);
          }
          else {
            emu_window = emulator_window_init(xx window_width, xx window_height);
            window_started = true;
          }

          // DEBUG_LOG = true;

        // Interrput 0x15: new framebuffer
        case 0x15;
          if !window_started {
            window_started = true;
            emu_window = emulator_window_init(64, 64); // fallback
          }

          emulator_window_draw_frame(
            *emu_window,
            array_view(emulator.ram, emulator.program_end, emu_window.screen_width*emu_window.screen_height*4)
          );

          new_input := emulator_window_handle_input(*emu_window);
          write_to_location(array_view(emulator.ram, INPUT_REGISTER, 2), cast(u16) new_input);

        // Interrput 0xFF: Emulator debug breakpoint
        case 0xFF;
          breakpoint();
      }
    }
    else {
      running = false;
    }
  }

  if OUTPUT_IMAGE_ON_EXIT {
    // write out the section of RAM designated in the homework as the "image" or "screen" area
    write_entire_file("image.data", cast(string) array_view(emulator.ram, IMAGE_ADDDRESS, IMAGE_SIZE));
  }
}

emulator_load_program_to_ram :: (using emulator: *Emulator, bytes: [] u8) {
  slice_copy(head(ram, bytes.count), bytes);
  program_end = xx bytes.count;
}

Emulate_Result :: struct {
  error: bool;

  interrupted: bool;
  interrupt_overflow: bool;
  interrupt_type: u8;
}

emulator_run :: (using emulator: *Emulator) -> Emulate_Result {
  result: Emulate_Result;

  running := true;
  while running {
    decode_info := decode(ram[ip], ram[ip+1]);

    if DEBUG_LOG {
      temp := tail(ram, ip);
      disassemble_one(decode_info, *temp);
    }

    last_ip := ip;

    step_result := emulator_step_one(decode_info, emulator);

    if DEBUG_LOG {
      print(
        "ax = %, bx = %, cx = %, dx = %, sp = %, bp = %, si = %, di = %, ip = % -> %, flags = [%]\n",
        get_integer_value(regs[Register.AX], word = true, signed = false),
        get_integer_value(regs[Register.BX], word = true, signed = false),
        get_integer_value(regs[Register.CX], word = true, signed = false),
        get_integer_value(regs[Register.DX], word = true, signed = false),
        get_integer_value(regs[Register.SP], word = true, signed = false),
        get_integer_value(regs[Register.BP], word = true, signed = false),
        get_integer_value(regs[Register.SI], word = true, signed = false),
        get_integer_value(regs[Register.DI], word = true, signed = false),
        last_ip,
        ip,
        tprint(
          "%0%0%0%0%0%0%0%0",
          ifx zf then "Z" else "",
          ifx pf then "P" else "",
          ifx sf then "S" else "",
          ifx of then "O" else "",
          ifx cf then "C" else "",
          ifx af then "A" else "",
          ifx df then "D" else "",
          ifx tf then "T" else "",
        ),
      );

      print(
        "[1000] = %\n[1002] = %\n[1004] = %\n[1006] = %\n====\n",
        read_ram(emulator, 1000, word = true, signed = false),
        read_ram(emulator, 1002, word = true, signed = false),
        read_ram(emulator, 1004, word = true, signed = false),
        read_ram(emulator, 1006, word = true, signed = false),
      );
    }

    // @Note: This is kind of a hack just for the homework. I would think normally an emulator would rely on the
    //        program having a halt instruction or infinite loop somewhere.
    if ip >= program_end  running = false;

    if step_result.interrupted {
      result = .{
        interrupted        = step_result.interrupted,
        interrupt_type     = step_result.interrupt_type,
        interrupt_overflow = step_result.interrupt_overflow,
      };

      running = false;
    }

    if step_result.error || last_ip == ip {
      result.error = true;
      log("Unrecognized opcode or instruction not implemented: %", FormatInt.{value = ram[ip], base = 16});
      running = false;
    }
  }

  return result;
}

Step_Result :: struct {
  error: bool;

  interrupted: bool;
  interrupt_overflow: bool;
  interrupt_type: u8;
}

emulator_step_one :: (info: DecodeInfo, using emulator: *Emulator) -> Step_Result {
  using info;

  result: Step_Result;

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
        apply_binary_op(emulator, bin_op, reg_loc, xx,no_check get_integer_value(ea_loc, word = w, signed = false));
      }
      else {
        apply_binary_op(emulator, bin_op, ea_loc,  xx,no_check get_integer_value(reg_loc, word = w, signed = false));
      }

    case .BIN_OP_I;
      imm_size := 1 + (cast(u16) (!s && w));

      ip += 2;
      ip_shift, ea_loc := eval_effective_address_or_reg(emulator, ip, mod = mod, r_m = r_m, word = w);
      ip += ip_shift;
      imm := read_immediate(emulator, word = !s && w, signed = s);
      ip += imm_size;

      apply_binary_op(emulator, bin_op, ea_loc, xx,no_check imm);

    case .BIN_OP_A;
      ip += 1;
      reg_loc := eval_reg(emulator, 0 /* .AX */, w);
      imm := read_immediate(emulator, word = w, signed = false);
      ip += 1 + cast(u16)w;
      apply_binary_op(emulator, bin_op, reg_loc, xx,no_check imm);

    case .GRP_1_R;
      ip += 1;
      reg_loc := eval_reg(emulator, reg, w);
      apply_group_1_op(emulator, un_op, reg_loc);

    case .GRP_1_M;
      ip += 2;
      ip_shift, ea_loc := eval_effective_address_or_reg(emulator, ip, mod = mod, r_m = r_m, word = w);
      ip += ip_shift;
      apply_group_1_op(emulator, un_op, ea_loc);

    case .JMP_DIR;
      ip += 1;
      imm := read_immediate(emulator, word = w, signed = true);
      ip += 1 + (cast(u16) w);
      apply_jump(emulator, offset = imm, link = link, long = false, absolute = false);

    case .JMP_LONG;
      // apply_jump(emulator, offset = imm, link = link, long = false, absolute = false);

    case .GRP_2;
      ip += 2;
      is_dec  := false;
      is_long := false;
      link    := false;

      ip_shift, ea_loc := eval_effective_address_or_reg(emulator, ip, mod = mod, r_m = r_m, word = w);
      ip += ip_shift;

      if #complete group_2_op == {
        case .DEC;
          is_dec = true;
          #through;
        case .INC;
          apply_inc_dec(emulator, is_dec = is_dec, arg = ea_loc);

        case .CALL_IND_LONG;
          is_long = true;
          link    = true;
          #through;
        case .CALL_IND;
          link    = true;
          #through;
        case .JMP_IND_LONG;
          is_long = true;
          #through;
        case .JMP_IND;
          jump_offset := get_integer_value(ea_loc, word = true, signed = true);
          apply_jump(emulator, offset = jump_offset, link = link, long = is_long, absolute = false);

        case .PUSH;
          value_to_push := get_integer_value(ea_loc, word = true, signed = false);
          stack_push(emulator, xx value_to_push);
      }

    case .COND_JMP;
      ip += 1;
      offset        := read_immediate(emulator, word = false, signed = true);
      ip += 1;
      condition_met := false;
      inverse       := (conditional_jump & 0b1) != 0;

      if #complete conditional_jump == {
        case .JO; #through;
        case .JNO;
          condition_met = of;
        case .JB_JNAE; #through;
        case .JNB_JAE;
          condition_met = cf;
        case .JE_JZ; #through;
        case .JNE_JNZ;
          condition_met = zf;
        case .JBE_JNA; #through;
        case .JNBE_JA;
          condition_met = cf || zf;
        case .JS; #through;
        case .JNS;
          condition_met = sf;
        case .JP_JPE; #through;
        case .JNP_JPO;
          condition_met = pf;
        case .JL_JNGE; #through;
        case .JNL_JGE;
          condition_met = sf ^ of;
        case .JLE_JNG; #through;
        case .JNLE_JG;
          condition_met = (sf ^ of) || zf;
      }

      if condition_met ^ inverse {
        apply_jump(emulator, offset, link = false, long  = false, absolute = false);
      }

    case .LOOP_JMP;
      ip += 1;
      offset        := read_immediate(emulator, word = false, signed = true);
      ip += 1;
      condition_met := false;
      cx_val        := get_integer_value(regs[Register.CX], word = true, signed = false);

      cx_val -= 1;
      write_to_location(regs[Register.CX], cast,no_check(u16) cx_val);
      if #complete loop_jump == {
        case .LOOPNZ_LOOPNE;
          condition_met = cx_val != 0 && !zf;
        case .LOOPZ_LOOPE;
          condition_met = cx_val != 0 && zf;
        case .LOOP;
          condition_met = cx_val != 0;
        case .JCXZ;
          condition_met = cx_val == 0;
      }

      if condition_met {
        apply_jump(emulator, offset, link = false, long  = false, absolute = false);
      }

    case .STACK_R;
      ip += 1;
      reg_loc := eval_reg(emulator, reg, w = true);

      if is_pop {
        popped_value := stack_pop(emulator);
        write_to_location(reg_loc, cast(u16) popped_value);
      }
      else {
        value_to_push := get_integer_value(reg_loc, word = true, signed = false);
        stack_push(emulator, xx value_to_push);
      }

    case .POP_RM;
      ip += 2;
      ip_shift, ea_loc := eval_effective_address_or_reg(emulator, ip, mod = mod, r_m = r_m, word = true);
      ip += ip_shift;
      popped_value := stack_pop(emulator);
      write_to_location(ea_loc, popped_value);

    case .STACK_S;

    case .RETURN;
      // @TODO: Support long return
      ip += 1;
      offset := ifx add_offset then read_immediate(emulator, word = true, signed = true) else 0;
      ip += 2;
      return_address := stack_pop(emulator);
      ip = xx,no_check ((cast(int) return_address) + offset);

    case .INC_DEC_R;
      ip += 1;
      reg_loc := eval_reg(emulator, reg, w = true);
      apply_inc_dec(emulator, is_dec = is_dec, arg = reg_loc);

    case .INTERRUPT;
      ip += 1;

      if #complete interrupt == {
        case .INT;
          result.interrupted    = true;
          result.interrupt_type = xx read_immediate(emulator, word = false, signed = false);
          ip += 1;

        case .INT3;
          result.interrupted    = true;
          result.interrupt_type = 3;

        case .INTO;
          if of {
            result.interrupted        = true;
            result.interrupt_overflow = true;
          }

        case .IRET;
          // @TODO
          result.error = true;
      }
  }

  return result;
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
      address_to_read = xx,no_check (address_to_read + offset);
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

read_reg :: (using emulator: Emulator, reg: Register, word: bool, signed: bool) -> s32 {
  return xx get_integer_value(regs[reg], word = word, signed = signed);
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

get_sign :: (value: int, count: int) -> bool {
  return (count == 1 && (value & 0b10000000)) || (count == 2 && (value & 0b10000000_00000000));
}

apply_binary_op :: (using emulator: *Emulator, op: Binary_Op, dest: Location, value: u16) {
  dest_val: int = get_integer_value(dest, word = dest.count == 2, signed = false);
  dest_sign    := get_sign(dest_val, dest.count);

  src_val: int = value;
  src_sign    := get_sign(value, dest.count);

  result: int;
  update_common_flags := false;

  if #complete op == {
    case .ADD;
      result = dest_val + src_val;
      cf     = (result & (0b1_00000000_00000000)) != 0;
      update_common_flags = true;
    case .OR;
      result = dest_val | src_val;
    case .ADC;
      result = dest_val + src_val + (cast(int) cf);
      cf     = (result & (0b1_00000000_00000000)) != 0;
      update_common_flags = true;
    case .SBB;
      result = dest_val - src_val - (cast(int) cf);
      cf     = src_val > dest_val;
      update_common_flags = true;
    case .AND;
      result = dest_val & src_val;
    case .SUB;
      result = dest_val - src_val;
      cf     = src_val > dest_val;
      update_common_flags = true;
    case .XOR;
      result = dest_val ^ src_val;
    case .CMP;
      result = dest_val - src_val;
      cf     = src_val > dest_val;
      update_common_flags = true;
  }

  // @TODO lots of the less important flags
  zf = result == 0;

  if update_common_flags {
    result_sign := get_sign(result, dest.count);
    sf = result_sign;
    of = dest_sign == src_sign && result_sign != dest_sign;
  }

  if op != .CMP {
    write_to_location(dest, cast,no_check(u16) result);
  }
}

apply_group_1_op :: (using emulator: *Emulator, op: Group_1_Op, arg: Location) {
  arg_val: int = get_integer_value(arg, word = arg.count == 2, signed = false);
  arg_sign    := get_sign(arg_val, arg.count);

  result: int;
  dest: Location;
  dest_val: int;

  if op >= .MUL && op <= .IDIV {
    dest     = array_view(regs[Register.AX], 0, arg.count);
    dest_val = get_integer_value(dest, word = dest.count == 2, signed = false);
  }
  else {
    dest     = arg;
    dest_val = arg_val;
  }
  dest_sign := get_sign(dest_val, dest.count);

  if #complete op == {
    case .TEST;
    case .NOT;
      result = ~dest_val;
    case .NEG;
      result = -dest_val;
      cf = result != 0;
    case .MUL;
      result = dest_val * arg_val;
      cf = result > 0xFFFF;
    case .IMUL;
      result = dest_val * ifx arg.count == 2 then (cast,no_check(s16) arg_val) else (cast,no_check(s8) arg_val);
      cf = dest_sign == arg_sign && get_sign(result, arg.count) != dest_sign;
    case .DIV;
      // @TODO Handle division by zero
      assert(arg_val != 0);
      result = dest_val / arg_val;
    case .IDIV;
      divisor := ifx arg.count == 2 then (cast,no_check(s16) arg_val) else (cast,no_check(s8) arg_val);
      // @TODO Handle division by zero
      assert(divisor != 0);
      result = dest_val / divisor;
  }

  // @TODO lots of the less important flags
  result_sign := get_sign(result, arg.count);
  zf = result == 0;
  sf = result_sign;

  if op == .NEG {
    of = (arg.count == 1 && arg_val == 0x80) || (arg.count == 2 && arg_val == 0x8000);
  }
  else {
    of = dest_sign == arg_sign && result_sign != dest_sign;
  }

  write_to_location(dest, cast,no_check(u16) result);
}

apply_inc_dec :: (using emulator: *Emulator, is_dec: bool, arg: Location) {
  arg_val: int = get_integer_value(arg, word = arg.count == 2, signed = false);
  arg_sign    := get_sign(arg_val, arg.count);

  dest      := arg;
  dest_val  := arg_val;
  dest_sign := get_sign(dest_val, dest.count);

  result:  int;

  if is_dec {
    result = dest_val - 1;
  }
  else {
    result = dest_val + 1;
  }

  // @TODO lots of the less important flags
  result_sign := get_sign(result, arg.count);
  zf = result == 0;
  sf = result_sign;
  of = dest_sign == arg_sign && result_sign != dest_sign;

  write_to_location(dest, cast,no_check(u16) result);
}

apply_jump :: (using emulator: *Emulator, offset: int, link: bool, long: bool, absolute: bool) {
  // @TODO: long jumps

  if link {
    stack_push(emulator, ip);
  }

  if absolute {
    ip = cast(u16) offset;
  }
  else {
    ip = cast(u16) (ip + offset);
  }
}

stack_push :: (using emulator: *Emulator, value: u16) {
  new_stack_ptr := cast,no_check(u16) (get_integer_value(regs[Register.SP], word = true, signed = false) - 2);
  stack_loc     := array_view(ram, new_stack_ptr, 2);

  write_to_location(regs[Register.SP], new_stack_ptr);
  write_to_location(stack_loc,         value);
}

stack_pop :: (using emulator: *Emulator) -> u16 {
  old_stack_ptr := cast,no_check(u16) get_integer_value(regs[Register.SP], word = true, signed = false);
  new_stack_ptr := cast,no_check(u16) (old_stack_ptr + 2);
  stack_loc     := array_view(ram, old_stack_ptr, 2);
  result        := read_ram(emulator, stack_loc, signed = false);

  write_to_location(regs[Register.SP], new_stack_ptr);

  return xx result;
}
