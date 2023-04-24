#import "Basic";
#import "File";

#load "emulate.jai";

main :: () {
  args := get_command_line_arguments();

  if args.count != 3 || (args[1] != "disassemble" && args[1] != "emulate") {
    print("Please pass in 'disassemble' or 'emulate', then one argument for the path to the file on which to perform that operation.\n");
    return;
  }

  if args[1] == "disassemble" {
    disassemble(xx read_entire_file(args[2]));
  }
  else {
    emulate(xx read_entire_file(args[2]));
  }
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
  GRP_1_R;   // Test, not, neg, mul, imul, div, idiv - on register
  GRP_1_M;   // Test, not, neg, mul, imul, div, idiv - on memory
  JMP_DIR;   // Jump/call (direct, short)
  JMP_LONG;  // Jump/call (direct, long)
  GRP_2;     // Jump/call (indirect), push, from register/memory
  COND_JMP;  // Conditional jumps
  LOOP_JMP;  // Miscellaneous conditional jumps (loopnz/loopne, loopz/loope, loop, jcxz)
  STACK_R;   // Push/pop from/to register
  STACK_S;   // Push/pop from/to segment register
  POP_RM;    // Pop to register/memory
  INC_DEC_R; // Increment/decrement register
  INTERRUPT; // Interrupts and interrupt return
  RETURN;    // Return
}

Binary_Op :: enum u8 #specified {
  ADD :: 0b000;
  OR  :: 0b001;
  ADC :: 0b010;
  SBB :: 0b011;
  AND :: 0b100;
  SUB :: 0b101;
  XOR :: 0b110;
  CMP :: 0b111;
}

Group_1_Op :: enum u8 #specified {
  TEST :: 0b000;
  NOT  :: 0b010;
  NEG  :: 0b011;
  MUL  :: 0b100;
  IMUL :: 0b101;
  DIV  :: 0b110;
  IDIV :: 0b111;
}

Shift_Op :: enum u8 #specified {
  ROL :: 0b000;
  ROR :: 0b001;
  RCL :: 0b010;
  RCR :: 0b011;
  SHL :: 0b100;
  SHR :: 0b101;
  SAR :: 0b111;
}

Group_2_Op :: enum u8 #specified {
  INC           :: 0b000;
  DEC           :: 0b001;
  CALL_IND      :: 0b010;
  CALL_IND_LONG :: 0b011;
  JMP_IND       :: 0b100;
  JMP_IND_LONG  :: 0b101;
  PUSH          :: 0b110;
}

Conditional_Jump :: enum u8 #specified {
  JO      :: 0b0000;
  JNO     :: 0b0001;
  JB_JNAE :: 0b0010;
  JNB_JAE :: 0b0011;
  JE_JZ   :: 0b0100;
  JNE_JNZ :: 0b0101;
  JBE_JNA :: 0b0110;
  JNBE_JA :: 0b0111;
  JS      :: 0b1000;
  JNS     :: 0b1001;
  JP_JPE  :: 0b1010;
  JNP_JPO :: 0b1011;
  JL_JNGE :: 0b1100;
  JNL_JGE :: 0b1101;
  JLE_JNG :: 0b1110;
  JNLE_JG :: 0b1111;
}

Loop_Jump :: enum u8 #specified {
  LOOPNZ_LOOPNE :: 0b00;
  LOOPZ_LOOPE   :: 0b01;
  LOOP          :: 0b10;
  JCXZ          :: 0b11;
}

Interrupt :: enum u8 #specified {
  INT3  :: 0b00;
  INT   :: 0b01;
  INTO  :: 0b10;
  IRET  :: 0b11;
}

bin_op_to_string : [8] string : .[
  "add", "or", "adc", "sbb", "and", "sub", "xor", "cmp"
];

group_1_op_to_string : [8] string : .[
  "test", "op1", "not", "neg", "mul", "imul", "div", "idiv"
];

shift_op_to_string : [8] string : .[
  "rol", "ror", "rcl", "rcr", "shl", "shr", "op6", "sar"
];

group_2_op_to_string : [8] string : .[
  "inc", "dec", "call", "call", "jmp", "jmp", "push", "op7"
];

conditional_jump_to_string : [16] string : .[
  "jo", "jno", "jb", "jnb", "je", "jne", "jbe", "jnbe", "js", "jns", "jp", "jnp", "jl", "jnl", "jle", "jnle"
];

loop_jump_to_string : [4] string : .[
  "loopnz", "loopz", "loop", "lcxz"
];

interrupt_to_string : [4] string : .[
  "int3", "int", "into", "iret"
];

opcode_table : [256] Opcode_Type : .[
  /* 0x00-0x0F */
  .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_A, .BIN_OP_A, .STACK_S,  .STACK_S,  .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_A, .BIN_OP_A, .STACK_S,  .NO_OP,
  /* 0x10-0x1F */
  .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_A, .BIN_OP_A, .STACK_S,  .STACK_S,  .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_A, .BIN_OP_A, .STACK_S,  .STACK_S,
  /* 0x20-0x2F */
  .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_A, .BIN_OP_A, .NO_OP,    .NO_OP,    .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_A, .BIN_OP_A, .NO_OP,    .NO_OP,
  /* 0x30-0x3F */
  .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_A, .BIN_OP_A, .NO_OP,    .NO_OP,    .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_R, .BIN_OP_A, .BIN_OP_A, .NO_OP,    .NO_OP,
  /* 0x40-0x4F */
  .INC_DEC_R,.INC_DEC_R,.INC_DEC_R,.INC_DEC_R,.INC_DEC_R,.INC_DEC_R,.INC_DEC_R,.INC_DEC_R,.INC_DEC_R,.INC_DEC_R,.INC_DEC_R,.INC_DEC_R,.INC_DEC_R,.INC_DEC_R,.INC_DEC_R,.INC_DEC_R,
  /* 0x50-0x5F */
  .STACK_R,  .STACK_R,  .STACK_R,  .STACK_R,  .STACK_R,  .STACK_R,  .STACK_R,  .STACK_R,  .STACK_R,  .STACK_R,  .STACK_R,  .STACK_R,  .STACK_R,  .STACK_R,  .STACK_R,  .STACK_R,
  /* 0x60-0x6F */
  .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,
  /* 0x70-0x7F */
  .COND_JMP, .COND_JMP, .COND_JMP, .COND_JMP, .COND_JMP, .COND_JMP, .COND_JMP, .COND_JMP, .COND_JMP, .COND_JMP, .COND_JMP, .COND_JMP, .COND_JMP, .COND_JMP, .COND_JMP, .COND_JMP,
  /* 0x80-0x8F */
  .BIN_OP_I, .BIN_OP_I, .BIN_OP_I, .BIN_OP_I, .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .MOV_RM2R, .MOV_RM2R, .MOV_RM2R, .MOV_RM2R, .MOV_S2RM, .NO_OP,    .MOV_RM2S, .POP_RM,
  /* 0x90-0x9F */
  .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .JMP_LONG, .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,
  /* 0xA0-0xAF */
  .MOV_M2A,  .MOV_M2A,  .MOV_A2M,  .MOV_A2M,  .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,
  /* 0xB0-0xBF */
  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,  .MOV_I2R,
  /* 0xC0-0xCF */
  .NO_OP,    .NO_OP,    .RETURN,   .RETURN,   .NO_OP,    .NO_OP,    .MOV_I2RM, .MOV_I2RM, .NO_OP,    .NO_OP,    .RETURN,   .RETURN,   .INTERRUPT,.INTERRUPT,.INTERRUPT,.INTERRUPT,
  /* 0xD0-0xDF */
  .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,
  /* 0xE0-0xEF */
  .LOOP_JMP, .LOOP_JMP, .LOOP_JMP, .LOOP_JMP, .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .JMP_DIR,  .JMP_DIR,  .JMP_LONG, .JMP_DIR,  .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,
  /* 0xF0-0xFF */
  .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .GRP_1_M,  .GRP_1_M,  .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .NO_OP,    .GRP_2,    .GRP_2,
];

DecodeInfo :: struct {
  op:               Opcode_Type;
  w, d, s:          bool;
  mod:              Mov_Mode;
  reg:              u8;
  r_m:              u8;
  bin_op:           Binary_Op;
  un_op:            Group_1_Op;
  shift_op:         Shift_Op;
  group_2_op:       Group_2_Op;
  conditional_jump: Conditional_Jump;
  loop_jump:        Loop_Jump;
  interrupt:        Interrupt;
  link:             bool;
  is_pop:           bool;
  add_offset:       bool;
  long:             bool;
  is_dec:           bool;
}

decode :: (first: u8, second: u8) -> DecodeInfo {
  info: DecodeInfo;
  info.op = opcode_table[first];

  if #complete info.op == {
    case .NO_OP;

    case .MOV_RM2R;
      info.d = ((first & 0b00000010) >> 1) != 0;
      info.w = (first & 0b00000001) != 0;

      info.mod = cast(Mov_Mode) ((second & 0b11000000) >> 6);
      info.reg = (second & 0b00111000) >> 3;
      info.r_m = (second & 0b00000111);

    case .MOV_I2RM;
      info.w = (first & 0b00000001) != 0;

      info.mod = cast(Mov_Mode) ((second & 0b11000000) >> 6);
      info.r_m = (second & 0b00000111);

    case .MOV_I2R;
      info.w   = ((first & 0b0001000) >> 3) != 0;
      info.reg = (first & 0b0000111);

    case .MOV_M2A;
      info.w   = (first & 0b0000001) != 0;

    case .MOV_A2M;
      info.w   = (first & 0b0000001) != 0;

    case .MOV_RM2S;

    case .MOV_S2RM;

    case .BIN_OP_R;
      info.bin_op = cast(Binary_Op) ((first & 0b00111000) >> 3);
      info.d      = ((first & 0b0000010) >> 1) != 0;
      info.w      = (first & 0b0000001) != 0;

      info.mod = cast(Mov_Mode) ((second & 0b11000000) >> 6);
      info.reg = (second & 0b00111000) >> 3;
      info.r_m = (second & 0b00000111);

    case .BIN_OP_I;
      info.s      = ((first & 0b0000010) >> 1) != 0;
      info.w      = (first & 0b0000001) != 0;
      info.mod    = cast(Mov_Mode) ((second & 0b11000000) >> 6);
      info.bin_op = cast(Binary_Op) ((second & 0b00111000) >> 3);
      info.r_m    = (second & 0b00000111);

    case .BIN_OP_A;
      info.bin_op = cast(Binary_Op) ((first & 0b00111000) >> 3);
      info.w      = (first & 0b0000001) != 0;
      info.reg    = 0 /* ax / al */;

    case .GRP_1_R;
      info.un_op = cast(Group_1_Op) (first & 0b00001000 >> 3);
      info.reg   = (first & 0b00000111);

    case .GRP_1_M;
      info.un_op = cast(Group_1_Op) (second & 0b00111000 >> 3);
      info.w     = (first & 0b1) != 0;
      info.mod   = cast(Mov_Mode) (second & 0b11000000) >> 6;
      info.r_m   = (second & 0b111);

    case .JMP_DIR;
      info.link = (first & 0b1) == 0;
      info.w    = (first & 0b00000010) == 0;

    case .JMP_LONG;
      info.link = (first & 0b00010000) != 0;

    case .GRP_2;
      info.mod        = cast(Mov_Mode) (second & 0b11000000) >> 6;
      info.group_2_op = cast(Group_2_Op) ((second & 0b00111000) >> 3);
      info.r_m        = (second & 0b111);
      info.w          = (first & 0b1) != 0;

    case .COND_JMP;
      info.conditional_jump = cast(Conditional_Jump) (first & 0b1111);

    case .LOOP_JMP;
      info.loop_jump = cast(Loop_Jump) (first & 0b00000011);

    case .STACK_R;
      info.reg    = (first & 0b11);
      info.is_pop = (first & 0b0000100) != 0;
      info.w      = true;

    case .STACK_S;
      info.reg    = (first & 0b0011000) >> 3;
      info.is_pop = (first & 0b1) != 0;
      info.w      = true;

    case .POP_RM;
      info.mod = cast(Mov_Mode) (second & 0b11000000) >> 6;
      info.r_m = (second & 0b111);
      info.w   = true;

    case .RETURN;
      info.add_offset = (first & 0b1) == 0;
      info.long       = (first & 0b00001000) != 0;

    case .INC_DEC_R;
      info.is_dec = (first & 0b00001000) != 0;
      info.reg    = (first & 0b00000111);
      info.w      = true;

    case .INTERRUPT;
      info.interrupt = cast(Interrupt) (first & 0b11);
  }

  return info;
}

disassemble :: (bytes: [] u8) {
  log("bits 16\n");

  runner := bytes;

  while runner.count {
    mark := get_temporary_storage_mark();
    defer set_temporary_storage_mark(mark);

    temp        := runner;
    decode_info := decode(runner[0], ifx runner.count == 1 then 0 else runner[1]);
    disassemble_one(decode_info, *runner);
    if runner.data == temp.data {
      log("Unrecognized opcode or instruction not implemented: %", FormatInt.{value = runner[0], base = 16});
      break;
    }
  }
}

disassemble_one :: (info: DecodeInfo, runner: *[] u8) {
  using info;

  if #complete info.op == {
    case .NO_OP;

    case .MOV_RM2R;
      consume_front(runner, 2);

      print_op("mov", effective_address_or_reg(runner, mod = mod, r_m = r_m, word = w), reg_string(reg, w), swap_args = d);

    case .MOV_I2RM;
      consume_front(runner, 2);

      print_op(
        "mov", effective_address_or_reg(runner, mod = mod, r_m = r_m, word = w),
        print_immediate(runner, w, signed = true, hex = false, size = true)
      );

    case .MOV_I2R;
      consume_front(runner, 1);
      print_op("mov", reg_string(reg, w), print_immediate(runner, w, signed = true, hex = false, size = true));

    case .MOV_M2A;
      consume_front(runner, 1);

      second_arg := tprint(
        "% [%]", ifx w then "word" else "byte",
        print_immediate(runner, w = w, signed = false, hex = false, size = false)
      );
      print_op("mov", ifx w then "ax" else "al", second_arg);

    case .MOV_A2M;
      consume_front(runner, 1);

      first_arg := tprint(
        "% [%]", ifx w then "word" else "byte",
        print_immediate(runner, w = w, signed = false, hex = false, size = false)
      );
      print_op("mov", first_arg, ifx w then "ax" else "al");

    case .MOV_RM2S;

    case .MOV_S2RM;

    case .BIN_OP_R;
      consume_front(runner, 2);
      print_op(bin_op_to_string[bin_op], effective_address_or_reg(runner, mod = mod, r_m = r_m, word = w), reg_string(reg, w), swap_args = d);

    case .BIN_OP_I;
      consume_front(runner, 2);
      print_op(
        bin_op_to_string[bin_op], effective_address_or_reg(runner, mod = mod, r_m = r_m, word = w),
        print_immediate(runner, w = !s && w, signed = s, hex = false, size = true)
      );

    case .BIN_OP_A;
      consume_front(runner, 1);
      print_op(
        bin_op_to_string[bin_op], ifx w then "ax" else "al",
        print_immediate(runner, w = w, signed = true, hex = false, size = true)
      );

    case .GRP_1_R;
      consume_front(runner, 1);
      print_op_1(group_1_op_to_string[un_op], reg_string(reg, w = true));

    case .GRP_1_M;
      consume_front(runner, 2);
      print_op_1(group_1_op_to_string[un_op], effective_address_or_reg(runner, mod = mod, r_m = r_m, word = w));

    case .JMP_DIR;
      consume_front(runner, 1);
      print_op_1(
        ifx link then "call" else "jmp",
        print_immediate(runner, w = w, signed = true, hex = false, size = false)
      );

    case .JMP_LONG;


    case .GRP_2;
      consume_front(runner, 2);
      print_op_1(
        group_2_op_to_string[group_2_op],
        effective_address_or_reg(runner, mod = mod, r_m = r_m, word = w)
      );

    case .COND_JMP;
      consume_front(runner, 1);
      print_op_1(
        conditional_jump_to_string[conditional_jump],
        print_immediate(runner, w = false, signed = true, hex = false, size = false)
      );

    case .LOOP_JMP;
      consume_front(runner, 1);
      print_op_1(
        loop_jump_to_string[loop_jump],
        print_immediate(runner, w = false, signed = true, hex = false, size = false)
      );

    case .STACK_R;
      consume_front(runner, 1);
      print_op_1(ifx is_pop then "pop" else "push", reg_string(reg, w = true));

    case .STACK_S;

    case .POP_RM;
      consume_front(runner, 2);
      print_op_1(
        "pop",
        effective_address_or_reg(runner, mod = mod, r_m = r_m, word = true)
      );

    case .RETURN;
      consume_front(runner, 1);
      op_string := ifx long then "retf" else "ret";
      if add_offset {
        print_op_1(op_string, print_immediate(runner, w = true, signed = true, hex = false, size = false));
      }
      else {
        log("%\n", op_string);
      }

    case .INC_DEC_R;
      consume_front(runner, 1);
      print_op_1(ifx is_dec then "dec" else "inc", reg_string(reg, w = true));

    case .INTERRUPT;
      consume_front(runner, 1);

      if #complete interrupt == {
        case .INT;
          print_op_1("int", print_immediate(runner, w = false, signed = false, hex = false, size = false));

        case .INT3; #through;
        case .INTO; #through;
        case .IRET;
          log("%\n", interrupt_to_string[interrupt]);
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
