#import "Basic";
#import "File";

disassemble :: (bytes: [] u8) -> string {
  reg_to_string : [2][] string : .[
    /* w == 0 */ .["al", "cl", "dl", "bl", "ah", "ch", "dh", "bh"],
    /* w == 1 */ .["ax", "cx", "dx", "bx", "sp", "bp", "si", "di"],
  ];

  Mov_Mode :: enum u8 #specified {
    mem_mode_no_disp :: 0b00;
    mem_mode_8_disp  :: 0b01;
    mem_mode_16_disp :: 0b10;
    reg_mode         :: 0b11;
  }

  builder: String_Builder;

  init_string_builder(*builder);

  print_to_builder(*builder, "bits 16\n");

  runner := bytes;

  while runner.count {
    first := runner[0];

    // Register/memory to/from register
    if      (first & 0b11111100) == 0b100010_00 {
      mark := get_temporary_storage_mark();
      defer set_temporary_storage_mark(mark);

      d := (first & 0b00000010) >> 1;
      w := (first & 0b00000001);

      mod := cast(Mov_Mode) ((runner[1] & 0b11000000) >> 6);
      reg := (runner[1] & 0b00111000) >> 3;
      r_m := (runner[1] & 0b00000111);

      if #complete mod == {
        case .mem_mode_no_disp; #through;
        case .mem_mode_8_disp;  #through;
        case .mem_mode_16_disp;

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

          op_length := ifx mod == .mem_mode_8_disp                    then 3 else
                       ifx mod == .mem_mode_16_disp                   then 4 else
                       ifx (mod == .mem_mode_no_disp && r_m == 0b110) then 4 else
                                                                           2;

          data_size := ifx w then "word" else "byte";

          offset: int;
          num_digits: int;
          add_or_sub: string;

          if op_length == 4 {
            offset = (cast(s64)runner[2]) | ((cast(s64)runner[3]) << 8);
            if !(mod == .mem_mode_no_disp && r_m == 0b110) {
              offset = cast,no_check(s16) offset;
            }
            add_or_sub = ifx offset < 0 then "-" else "+";
            num_digits = 5;
          }
          else if op_length == 3 {
            offset = (cast,no_check(s8)runner[2]);
            add_or_sub = ifx offset < 0 then "-" else "+";
            num_digits = 3;
          }

          if offset < 0  offset *= -1;

          addr := tprint(effective_addr_table[r_m][mod], data_size, add_or_sub, FormatInt.{value = offset, base = 16, minimum_digits = num_digits});

          if d {
            print_to_builder(*builder, "mov %, %\n", reg_to_string[w][reg], addr);
          }
          else {
            print_to_builder(*builder, "mov %, %\n", addr, reg_to_string[w][reg]);
          }

          consume_front(*runner, op_length);

        case .reg_mode;
          dest, src: u8;
          consume_front(*runner, 2);
          if d  dest, src = reg, r_m;
          else  dest, src = r_m, reg;
          print_to_builder(*builder, "mov %, %\n", reg_to_string[w][dest], reg_to_string[w][src]);
      }
    }
    // Immediate to register/memory
    else if (first & 0b11111110) == 0b1100011_0 {

    }
    // Immediate to register
    else if (first & 0b11111000) == 0b1011_0000 {

    }
    // Memory to accumulator
    else if (first & 0b11111110) == 0b1010000_0 {

    }
    // Accumulator to memory
    else if (first & 0b11111110) == 0b1010001_0 {

    }
    // Register/memory to segment register
    else if (first & 0b11111111) == 0b10001110 {

    }
    // Segment register to register/memory
    else if (first & 0b11111111) == 0b10001100 {

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

main :: () {
  args := get_command_line_arguments();

  if args.count != 2 {
    print("Please pass one argument for the path to the file to disassemble\n");
    return;
  }

  print(disassemble(xx read_entire_file(args[1])));

  return;
}