/*
  Sum_Type - Basic sum type / tagged union with compile-time-checked match macro
*/

Sum_Type :: struct(value_types: ..Type) {
  // Generate fields
  #insert -> string {
    builder: String_Builder;
    init_string_builder(*builder);

    print_to_builder(*builder, "Tag_Type :: enum u8 {\n");

    for 0..value_types.count-1 {
      print_to_builder(*builder, "  TYPE_%;\n", it);
    }

    print_to_builder(*builder, "}\n");
    print_to_builder(*builder, "tag: Tag_Type;\n");
    print_to_builder(*builder, "data: union {\n");

    for value_types {
      print_to_builder(*builder, "  value_%: %;\n", it_index, it);
    }

    print_to_builder(*builder, "}\n");
    result := builder_to_string(*builder);
    // print(result);
    return result;
  }

  // Generate macro called "match", to be used like:
  // Your_Sum_Type.match(*sum_type_variable,
  //   int,    #code { /* ... */ },
  //   float,  #code { /* ... */ },
  //   string, #code { /* ... */ },
  // );
  // Inside each of the #code blocks will have declared a local called "it" that's a pointer of the type of the sum type's
  // potential current value, in the order that you declared the types. The type arguments on the left do nothing other
  // than to allow nagging that you've declared them in-order. I don't have a better solution at the time being.
  #insert -> string {
    builder: String_Builder;
    init_string_builder(*builder);

    print_to_builder(*builder, "match :: (sum: *Sum_Type,\n");
    for 0..value_types.count-1 {
      print_to_builder(*builder, "  $type_%: Type,\n", it);
      print_to_builder(*builder, "  code_%: Code%\n", it,  ifx it == value_types.count-1 then "" else ",");
    }
    print_to_builder(*builder, ") #expand {\n");

    for value_types {
      print_to_builder(*builder, "  #assert (type_% == type_of(sum.data.value_%))", it_index, it_index);
      print_to_builder(*builder, "\"Type argument #% doesn't match the order the sum type was declared with! Expected `%`.\";\n", it_index+1, it);
    }

    print_to_builder(*builder, "  if #complete sum.tag == {\n");
    for 0..value_types.count-1 {
      print_to_builder(*builder, "    case .TYPE_%;\n", it);
      print_to_builder(*builder, "      it := *sum.data.value_%;\n", it);
      print_to_builder(*builder, "      #insert,scope() code_%;\n", it);
    }
    print_to_builder(*builder, "  }\n");

    print_to_builder(*builder, "}\n");

    result := builder_to_string(*builder);
    // print(result);
    return result;
  }

  // To be used like:
  // Your_Sum_Type.match_one(*sum_type_variable,
  //   int,       #code { /* ... */ },
  //   /* else */ #code { /* ... */ },
  // );
  // You use this one if you only mean to handle one case but don't care about the rest, even if another type were to
  // be added to the sum type down the road. The "else" case will have declared "it" that's a pointer to the current
  // value's type.
  match_one :: (sum: *Sum_Type, $type: Type, type_case: Code, else_case: Code) #expand {
    field_id :: #run check_type_in_sum(type_of(<<sum), type);

    // @CompileSpeed: This must necessarily generate new code on every invocation. Is this bad?
    #insert -> string {
      builder: String_Builder;
      init_string_builder(*builder);

      print_to_builder(*builder, "  if #complete sum.tag == {\n");
      print_to_builder(*builder, "    case .TYPE_%;\n", field_id);
      print_to_builder(*builder, "      it := *sum.data.value_%;\n", field_id);
      print_to_builder(*builder, "      #insert,scope() type_case;\n");
      for 0..value_types.count-1 {
        if it == field_id continue;
        print_to_builder(*builder, "    case .TYPE_%;\n", it);
        print_to_builder(*builder, "      it := *sum.data.value_%;\n", it);
        print_to_builder(*builder, "      #insert,scope() else_case;\n");
      }
      print_to_builder(*builder, "  }\n");
      result := builder_to_string(*builder);
      // print(result);
      return result;
    }
  }
}

set :: inline (sum: *Sum_Type, value: $T) {
  field_id :: #run check_type_in_sum(type_of(<<sum), T);

  #insert #run tprint("sum.tag = .TYPE_%; sum.data.value_% = value;", field_id, field_id);
}

isa :: inline (sum: Sum_Type, $T: Type) -> *T {
  field_id :: #run check_type_in_sum(type_of(sum), T);

  #insert #run tprint("return ifx sum.tag == .TYPE_% then *sum.data.value_% else null;", field_id, field_id);
}

operator == :: inline (sum: Sum_Type, value: $T) -> bool #symmetric {
  field_id :: #run check_type_in_sum(type_of(sum), T);

  #insert #run tprint("return sum.tag == .TYPE_% && sum.data.value_% == value;", field_id, field_id);
}

#scope_file

#import "Basic";

type_field_in_sum :: ($sum_type: Type, value_type: Type) -> int {
  sum_type_info   := cast(*Type_Info_Struct) sum_type;
  value_type_info := cast(*Type_Info) value_type;

  for (cast(*Type_Info_Struct) type_of(sum_type.{}.data)).members {
    if it.type == value_type_info  return it_index; // @Hack: Hope they're in order declared?
  }

  return -1;
}

check_type_in_sum :: ($sum_type: Type, value_type: Type) -> int #expand {
  field_id :: #run type_field_in_sum(sum_type, value_type);
  #insert #run tprint("#assert (field_id != -1) \"Sum type `%` doesn't include the type `%`!\";", sum_type, value_type);
  return field_id;
}
