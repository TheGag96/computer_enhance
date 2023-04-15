#import "Basic";
#import "File";

main :: () {
  args := get_command_line_arguments();

  if args.count != 2 {
    print("Please pass one argument for the path to the file to disassemble\n");
    return;
  }

  disassemble(xx read_entire_file(args[1]));

  return;
}

reg_to_string : [2][] string : .[
  /* w == 0 */ .["al", "cl", "dl", "bl", "ah", "ch", "dh", "bh"],
  /* w == 1 */ .["ax", "cx", "dx", "bx", "sp", "bp", "si", "di"],
];

Mov_Mode :: enum u8 #specified {
  MEM_MODE_NO_DISP :: 0b00;
  MEM_MODE_8_DISP  :: 0b01;
  MEM_MODE_16_DISP :: 0b10;
  REG_MODE         :: 0b11;
}

Opcode_Type :: enum u8 {
  NO_OP;     // No operation
  MOV_RM2R;  // Register/memory to/from register
  MOV_I2RM;  // Immediate to register/memory
  MOV_I2R;   // Immediate to register
  MOV_M2A;   // Memory to accumulator
  MOV_A2M;   // Accumulator to memory
  MOV_RM2S;  // Register/memory to segment register
  MOV_S2RM;  // Segment register to register/memory
  BIN_OP_R;  // Binary operation - register/memory and register to either
  BIN_OP_I;  // Binary operation - immediate from register/memory
  BIN_OP_A;  // Binary operation - immediate from accumulator
  // more to come...
}

Binary_Op :: enum u8 #specified {
  ADD :: 0b000;
  ADC :: 0b010;
  SBB :: 0b011;
  SUB :: 0b101;
  CMP :: 0b111;
}

bin_op_to_string : [8] string : .[
  "add", "op1", "adc", "op3", "sbb", "sub", "op6", "cmp"
];

opcode_table : [256] Opcode_Type : .[
  /* 0x00-0x0F */
  .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_A, .BIN_OP_A, .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,
  /* 0x10-0x1F */
  .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_A, .BIN_OP_A, .NO_OP,    .NO_OP,    .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_A, .BIN_OP_A, .NO_OP,    .NO_OP,
  /* 0x20-0x2F */
  .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_A, .BIN_OP_A, .NO_OP,    .NO_OP,
  /* 0x30-0x3F */
  .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_A, .BIN_OP_A, .NO_OP,    .NO_OP,
  /* 0x40-0x4F */
  .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,
  /* 0x50-0x5F */
  .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,
  /* 0x60-0x6F */
  .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,
  /* 0x70-0x7F */
  .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,
  /* 0x80-0x8F */
  .BIN_OP_I, .BIN_OP_I, .BIN_OP_I, .BIN_OP_I, .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .MOV_RM2R, .MOV_RM2R, .MOV_RM2R, .MOV_RM2R, .MOV_S2RM, .NO_OP,    .MOV_RM2S, .NO_OP,
  /* 0x90-0x9F */
  .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,
  /* 0xA0-0xAF */
  .MOV_M2A,  .MOV_M2A,  .MOV_A2M,  .MOV_A2M,  .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,
  /* 0xB0-0xBF */
  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,
  /* 0xC0-0xCF */
  .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .MOV_I2RM, .MOV_I2RM, .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,
  /* 0xD0-0xDF */
  .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,
  /* 0xE0-0xEF */
  .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,
  /* 0xF0-0xFF */
  .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,
];

disassemble :: (bytes: [] u8) {
  log("bits 16\n");

  runner := bytes;

  while runner.count {
    mark := get_temporary_storage_mark();
    defer set_temporary_storage_mark(mark);

    first := runner[0];

    if #complete opcode_table[first] == {
      case .NO_OP;

      case .MOV_RM2R;
        d := ((first & 0b00000010) >> 1) != 0;
        w := (first & 0b00000001) != 0;

        mod := cast(Mov_Mode) ((runner[1] & 0b11000000) >> 6);
        reg := (runner[1] & 0b00111000) >> 3;
        r_m := (runner[1] & 0b00000111);

        consume_front(*runner, 2);

        print_op("mov", effective_address_or_reg(*runner, mod = mod, r_m = r_m, word = w), reg_string(reg, w), swap_args = d);

      case .MOV_I2RM;
        w := (first & 0b00000001) != 0;

        mod := cast(Mov_Mode) ((runner[1] & 0b11000000) >> 6);
        r_m := (runner[1] & 0b00000111);

        consume_front(*runner, 2);

        print_op(
          "mov", effective_address_or_reg(*runner, mod = mod, r_m = r_m, word = w),
          print_immediate(*runner, w, signed = true, hex = false, size = true)
        );

      case .MOV_I2R;
        w   := ((first & 0b0001000) >> 3) != 0;
        reg := (first & 0b0000111);

        consume_front(*runner, 1);
        print_op("mov", reg_string(reg, w), print_immediate(*runner, w, signed = true, hex = false, size = true));

      case .MOV_M2A;
        w   := (first & 0b0000001) != 0;

        consume_front(*runner, 1);

        second_arg := tprint(
          "% [%]", ifx w then "word" else "byte",
          print_immediate(*runner, w = w, signed = false, hex = false, size = false)
        );
        print_op("mov", ifx w then "ax" else "al", second_arg);

      case .MOV_A2M;
        w   := (first & 0b0000001) != 0;

        consume_front(*runner, 1);

        first_arg := tprint(
          "% [%]", ifx w then "word" else "byte",
          print_immediate(*runner, w = w, signed = false, hex = false, size = false)
        );
        print_op("mov", first_arg, ifx w then "ax" else "al");

      case .MOV_RM2S;

      case .MOV_S2RM;

      case .BIN_OP_R;
        bin_op := cast(Binary_Op) ((first & 0b00111000) >> 3);
        d      := ((first & 0b0000010) >> 1) != 0;
        w      := (first & 0b0000001) != 0;

        mod := cast(Mov_Mode) ((runner[1] & 0b11000000) >> 6);
        reg := (runner[1] & 0b00111000) >> 3;
        r_m := (runner[1] & 0b00000111);

        consume_front(*runner, 2);
        print_op(bin_op_to_string[bin_op], effective_address_or_reg(*runner, mod = mod, r_m = r_m, word = w), reg_string(reg, w), swap_args = d);

      case .BIN_OP_I;
        s      := ((first & 0b0000010) >> 1) != 0;
        w      := (first & 0b0000001) != 0;

        mod    := cast(Mov_Mode)  ((runner[1] & 0b11000000) >> 6);
        bin_op := cast(Binary_Op) ((runner[1] & 0b00111000) >> 3);
        r_m    := (runner[1] & 0b00000111);

        imm_size := 1 + (cast(int) (!s && w));

        consume_front(*runner, 2);
        second_arg := print_immediate(*runner, w = imm_size == 2, signed = s, hex = false, size = true);
        print_op(bin_op_to_string[bin_op], effective_address_or_reg(*runner, mod = mod, r_m = r_m, word = w), second_arg);

      case .BIN_OP_A;
        bin_op := cast(Binary_Op) ((first & 0b00111000) >> 3);
        w      := (first & 0b0000001) != 0;
        reg    := ifx w then "ax" else "al";

        consume_front(*runner, 1);
        print_op(
          bin_op_to_string[bin_op], ifx w then "ax" else "al",
          print_immediate(*runner, w = w, signed = true, hex = false, size = true)
        );
    }
  }
}

consume_front :: inline (arr: * $T, skip: s64) -> T {
  result: T = ---;

  assert(skip >= 0 && skip <= arr.count);
  result.data  = arr.data;
  result.count = skip;

  arr.data  += skip;
  arr.count -= skip;

  return result;
}

slice_to_end :: inline (arr: $T, skip: s64) -> T {
  result: T = ---;

  assert(skip >= 0 && skip <= arr.count);
  result.data  = arr.data  + skip;
  result.count = arr.count - skip;

  return result;
}

get_integer_value :: (arr: [] u8, word: bool, signed: bool) -> (int) {
  result: int;

  if word {
    result = (cast(s64)arr[0]) | ((cast(s64)arr[1]) << 8);
    if signed {
      result = cast,no_check(s16) result;
    }
  }
  else {
    result = (cast,no_check(s64)arr[0]);
    if signed {
      result = cast,no_check(s8) result;
    }
  }

  return result;
}

effective_address :: (bytes: *[] u8, mod: Mov_Mode, r_m: u8, word: bool) -> string {
  displacements : [8] string : .[
    "bx + si",
    "bx + di",
    "bp + si",
    "bp + di",
    "si",
    "di",
    "bp",
    "bx",
  ];

  direct := mod == .MEM_MODE_NO_DISP && r_m == 0b110;

  offset: int;
  formatted_offset: FormatInt;
  num_digits: int;
  add_or_sub: string;

  data_size := ifx word then "word" else "byte";

  if mod != .MEM_MODE_NO_DISP || direct {
    disp_16 := mod == .MEM_MODE_16_DISP || direct;
    offset = get_integer_value(<<bytes, word = disp_16, signed = !direct);
    add_or_sub = ifx offset < 0 then "-" else "+";
    num_digits = ifx disp_16 then 5 else 3;

    if offset < 0  offset *= -1;

    consume_front(bytes, 1 + (cast(int)disp_16));
    formatted_offset = FormatInt.{value = offset, base = 16, minimum_digits = num_digits};
  }

  if direct {
    return tprint("% [%h]", data_size, formatted_offset);
  }
  else {
    if mod != .MEM_MODE_NO_DISP {
      return tprint("% [% % %h]", data_size, displacements[r_m], add_or_sub, formatted_offset);
    }
    else {
      return tprint("% [%]", data_size, displacements[r_m]);
    }
  }
}

effective_address_or_reg :: (bytes: *[] u8, mod: Mov_Mode, r_m: u8, word: bool) -> string {
  if #complete mod == {
    case .MEM_MODE_NO_DISP; #through;
    case .MEM_MODE_8_DISP;  #through;
    case .MEM_MODE_16_DISP;
      return effective_address(bytes, mod = mod, r_m = r_m, word = word);

    case .REG_MODE;
      return reg_string(r_m, word);
  }
}

displacement_op_size :: (mod: Mov_Mode, r_m: u8) -> int {
  return ifx mod == .MEM_MODE_8_DISP                    then 3 else
         ifx mod == .MEM_MODE_16_DISP                   then 4 else
         ifx (mod == .MEM_MODE_NO_DISP && r_m == 0b110) then 4 else
                                                             2;
}

reg_string :: (reg: int, w: bool) -> string {
  return reg_to_string[cast(int)w][reg];
}

print_immediate :: (bytes: *[] u8, w: bool, signed: bool, hex: bool, size: bool) -> string {
  value     := get_integer_value(<<bytes, word = w, signed = signed);
  consume_front(bytes, 1 + (cast(int)w));

  data_size := ifx size then (ifx w then "word " else "byte ") else "";
  if hex {
    num_digits := ifx w then 5 else 3;
    return tprint("%0%h", data_size, FormatInt.{value = value, base = 16, minimum_digits = num_digits});
  }
  else {
    return tprint("%0%", data_size, value);
  }
}

print_op :: (opcode: string, arg1: string, arg2: string, swap_args: bool = false) {
  first, second := arg1, arg2;
  if swap_args {
    first  = arg2;
    second = arg1;
  }

  log("% %, %", opcode, first, second);
}

print_op_1 :: (opcode: string, arg: string) {
  log("% %", opcode, arg);
}
