#import "Basic";
#import "File";

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

disassemble :: (bytes: [] u8) -> string {
  builder: String_Builder;

  init_string_builder(*builder);

  print_to_builder(*builder, "bits 16\n");

  runner := bytes;

  while runner.count {
    first := runner[0];

    if #complete opcode_table[first] == {
      case .NO_OP;

      case .MOV_RM2R;
        mark := get_temporary_storage_mark();
        defer set_temporary_storage_mark(mark);

        d := (first & 0b00000010) >> 1;
        w := (first & 0b00000001);

        mod := cast(Mov_Mode) ((runner[1] & 0b11000000) >> 6);
        reg := (runner[1] & 0b00111000) >> 3;
        r_m := (runner[1] & 0b00000111);

        if #complete mod == {
          case .MEM_MODE_NO_DISP; #through;
          case .MEM_MODE_8_DISP;  #through;
          case .MEM_MODE_16_DISP;

            op_length := ifx mod == .MEM_MODE_8_DISP                    then 3 else
                         ifx mod == .MEM_MODE_16_DISP                   then 4 else
                         ifx (mod == .MEM_MODE_NO_DISP && r_m == 0b110) then 4 else
                                                                             2;

            consume_front(*runner, 2);
            addr := consume_effective_address(*runner, mod = mod, r_m = r_m, word = xx w);

            if d {
              print_to_builder(*builder, "mov %, %\n", reg_to_string[w][reg], addr);
            }
            else {
              print_to_builder(*builder, "mov %, %\n", addr, reg_to_string[w][reg]);
            }

          case .REG_MODE;
            dest, src: u8;
            consume_front(*runner, 2);
            if d  dest, src = reg, r_m;
            else  dest, src = r_m, reg;
            print_to_builder(*builder, "mov %, %\n", reg_to_string[w][dest], reg_to_string[w][src]);
        }

      case .MOV_I2RM;
        w := (first & 0b00000001);

        mod := cast(Mov_Mode) ((runner[1] & 0b11000000) >> 6);
        r_m := (runner[1] & 0b00000111);

        data_size := ifx w then "word" else "byte";

        if #complete mod == {
          case .MEM_MODE_NO_DISP; #through;
          case .MEM_MODE_8_DISP;  #through;
          case .MEM_MODE_16_DISP;

            op_length := (ifx mod == .MEM_MODE_8_DISP                    then 3 else
                          ifx mod == .MEM_MODE_16_DISP                   then 4 else
                          ifx (mod == .MEM_MODE_NO_DISP && r_m == 0b110) then 4 else
                                                                              2) + 1 + w;

            consume_front(*runner, 2);
            addr := consume_effective_address(*runner, mod = mod, r_m = r_m, word = xx w);

            value := get_integer_value(runner, word = xx w, signed = true);
            consume_front(*runner, 1 + w);
            print_to_builder(*builder, "mov %, % %\n", addr, data_size, value);

          case .REG_MODE;
            value     := get_integer_value(slice_to_end(runner, 2), word = xx w, signed = true);

            consume_front(*runner, 3 + w);

            print_to_builder(*builder, "mov %, % %\n", reg_to_string[w][r_m], data_size, value);
        }

      case .MOV_I2R;
        w   := (first & 0b0001000) >> 3;
        reg := (first & 0b0000111);

        value     := get_integer_value(slice_to_end(runner, 1), word = xx w, signed = true);
        data_size := ifx w then "word" else "byte";

        consume_front(*runner, 2 + w);

        print_to_builder(*builder, "mov %, % %\n", reg_to_string[w][reg], data_size, value);

      case .MOV_M2A;
        w   := (first & 0b0000001);

        value      := get_integer_value(slice_to_end(runner, 1), word = true, signed = false);
        data_size  := ifx w then "word" else "byte";
        reg        := ifx w then "ax" else "al";
        num_digits := 5;

        consume_front(*runner, 3);

        print_to_builder(*builder, "mov %, % [%h]\n", reg, data_size, FormatInt.{value = value, base = 16, minimum_digits = num_digits});

      case .MOV_A2M;
        w   := (first & 0b0000001);

        value      := get_integer_value(slice_to_end(runner, 1), word = true, signed = false);
        data_size  := ifx w then "word" else "byte";
        reg        := ifx w then "ax" else "al";
        num_digits := 5;

        consume_front(*runner, 3);

        print_to_builder(*builder, "mov %, % [%h]\n", reg, data_size, FormatInt.{value = value, base = 16, minimum_digits = num_digits});

      case .MOV_RM2S;

      case .MOV_S2RM;

      case .BIN_OP_R;
        bin_op := cast(Binary_Op) ((first & 0b00111000) >> 3);
        d      := (first & 0b0000010) >> 1;
        w      := (first & 0b0000001);

        mod := cast(Mov_Mode) ((runner[1] & 0b11000000) >> 6);
        reg := (runner[1] & 0b00111000) >> 3;
        r_m := (runner[1] & 0b00000111);

        data_size := ifx w then "word" else "byte";

        bin_op_string := bin_op_to_string[bin_op];

        if #complete mod == {
          case .MEM_MODE_NO_DISP; #through;
          case .MEM_MODE_8_DISP;  #through;
          case .MEM_MODE_16_DISP;

            op_length := ifx mod == .MEM_MODE_8_DISP                    then 3 else
                         ifx mod == .MEM_MODE_16_DISP                   then 4 else
                         ifx (mod == .MEM_MODE_NO_DISP && r_m == 0b110) then 4 else
                                                                             2;

            consume_front(*runner, 2);
            addr := consume_effective_address(*runner, mod = mod, r_m = r_m, word = xx w);

            if d {
              print_to_builder(*builder, "% %, %\n", bin_op_string, reg_to_string[w][reg], addr);
            }
            else {
              print_to_builder(*builder, "% %, %\n", bin_op_string, addr, reg_to_string[w][reg]);
            }

          case .REG_MODE;
            dest, src: u8;
            consume_front(*runner, 2);
            if d  dest, src = reg, r_m;
            else  dest, src = r_m, reg;
            print_to_builder(*builder, "% %, %\n", bin_op_string, reg_to_string[w][dest], reg_to_string[w][src]);
        }

      case .BIN_OP_I;
        s      := (first & 0b0000010) >> 1;
        w      := (first & 0b0000001);

        mod    := cast(Mov_Mode)  ((runner[1] & 0b11000000) >> 6);
        bin_op := cast(Binary_Op) ((runner[1] & 0b00111000) >> 3);
        r_m    := (runner[1] & 0b00000111);

        data_size     := ifx w then "word" else "byte";
        bin_op_string := bin_op_to_string[bin_op];

        imm_size := 1 + (cast(int) (s == 0 && w == 1));

        if #complete mod == {
          case .MEM_MODE_NO_DISP; #through;
          case .MEM_MODE_8_DISP;  #through;
          case .MEM_MODE_16_DISP;

            op_length := (ifx mod == .MEM_MODE_8_DISP                    then 3 else
                          ifx mod == .MEM_MODE_16_DISP                   then 4 else
                          ifx (mod == .MEM_MODE_NO_DISP && r_m == 0b110) then 4 else
                                                                              2) + imm_size;

            consume_front(*runner, 2);
            addr := consume_effective_address(*runner, mod = mod, r_m = r_m, word = xx w);

            value := get_integer_value(runner, word = imm_size == 2, signed = xx s);
            consume_front(*runner, imm_size);
            print_to_builder(*builder, "% %, % %\n", bin_op_string, addr, data_size, value);

          case .REG_MODE;
            value     := get_integer_value(slice_to_end(runner, 2), word = imm_size == 2, signed = xx s);

            consume_front(*runner, 2 + imm_size);

            print_to_builder(*builder, "% %, % %\n", bin_op_string, reg_to_string[w][r_m], data_size, value);
        }

      case .BIN_OP_A;
        bin_op := cast(Binary_Op) ((first & 0b00111000) >> 3);
        w      := (first & 0b0000001);
        reg    := ifx w then "ax" else "al";

        bin_op_string := bin_op_to_string[bin_op];

        value     := get_integer_value(slice_to_end(runner, 1), word = xx w, signed = true);
        data_size := ifx w then "word" else "byte";

        consume_front(*runner, 2 + w);

        print_to_builder(*builder, "% %, % %\n", bin_op_string, reg, data_size, value);
    }
  }

  return builder_to_string(*builder);
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

main :: () {
  args := get_command_line_arguments();

  if args.count != 2 {
    print("Please pass one argument for the path to the file to disassemble\n");
    return;
  }

  print(disassemble(xx read_entire_file(args[1])));

  return;
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

consume_effective_address :: (bytes: *[] u8, mod: Mov_Mode, r_m: u8, word: bool) -> string {
  effective_addr_table : [8][3] string : .[
    .["% [bx + si]", "% [bx + si % %h]", "% [bx + si % %h]"],
    .["% [bx + di]", "% [bx + di % %h]", "% [bx + di % %h]"],
    .["% [bp + si]", "% [bp + si % %h]", "% [bp + si % %h]"],
    .["% [bp + di]", "% [bp + di % %h]", "% [bp + di % %h]"],
    .["% [si]",      "% [si % %h]",      "% [si % %h]"     ],
    .["% [di]",      "% [di % %h]",      "% [di % %h]"     ],
    .["% [%3h]",     "% [bp % %h]",      "% [bp % %h]"     ],
    .["% [bx]",      "% [bx % %h]",      "% [bx % %h]"     ],
  ];

  direct := mod == .MEM_MODE_NO_DISP && r_m == 0b110;

  offset: int;
  num_digits: int;
  add_or_sub: string;

  disp_16 := mod == .MEM_MODE_16_DISP || direct;
  data_size := ifx word then "word" else "byte";

  if mod != .MEM_MODE_NO_DISP || direct {
    offset = get_integer_value(<<bytes, word = disp_16, signed = !direct);
    add_or_sub = ifx offset < 0 then "-" else "+";
    num_digits = ifx disp_16 then 5 else 3;

    if offset < 0  offset *= -1;

    consume_front(bytes, 1 + (cast(int)disp_16));
  }

  return tprint(effective_addr_table[r_m][mod], data_size, add_or_sub, FormatInt.{value = offset, base = 16, minimum_digits = num_digits});
}