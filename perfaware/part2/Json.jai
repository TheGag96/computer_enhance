#import "Basic";
#import "File";
#import "Hash_Table";

#load "Sum_Type.jai";

Json :: struct {
  root: Json_Val;
}

Json_Val :: Sum_Type(*Json_Object, *Json_Array, *Json_Literal);

Json_Object :: struct {
  fields: Table(string, Json_Val);
};

Json_Array :: struct {
  array: [] Json_Val;
};

Json_Literal_Kind :: enum u8 {
  STRING;
  NUMBER;
  BOOLEAN;
  NULL;
}

Json_Literal :: struct {
  kind: Json_Literal_Kind;
  value: string;
}

//////////////////////////////

Token_Type :: enum u8 {
  STRING_LITERAL;
  NUMBER_LITERAL;
  BOOLEAN_LITERAL;
  NULL_LITERAL;
  PUNCTUATION;
}

Token :: struct {
  type: Token_Type;
  #as text: string;
  line, column: int;
}


lex_json_string :: (text: string) -> (tokens: [] Token, success: bool) {
  runner := text;
  result: [..] Token;

  WHITESPACE_CHARS :: " \t\n\r";  // @Note: doesn't include unicode whitespace

  char_in_string :: (char: u8, str: string) -> bool {
    for :by_code_point str {
      if char == it return true;
    }
    return false;
  }

  is_digit :: inline (char: u8) -> bool {
    return char >= #char "0" && char <= #char "9";
  }

  column := 1;
  line   := 1;

  lex_error :: ($format: string, args: ..Any) #expand {
    log((#run tprint("JSON lex error (line %%, column %%): %", format)), ..args, flags = .ERROR);
    `return Token.[], false;
  }

  while runner.count {
    if char_in_string(runner[0], "{}[],:") {
      array_add(*result, Token.{.PUNCTUATION, slice(runner, 0, 1), line, column});
      column += 1;
      runner = slice(runner, 1);
    }
    else if runner[0] == #char "\"" {
      closing_quote_index := 0;
      for :by_code_point slice(runner, 1) {
        if it == #char "\"" {
          closing_quote_index = it_index + 1; // account for having sliced runner by 1
          break;
        }
        else if it == #char "\r" {
          lex_error("Expected a `\"` to end a string literal, but found a carriage return!", line, column + it_index);
        }
        else if it == #char "\n" {
          lex_error("Expected a `\"` to end a string literal, but found a line break!", line, column + it_index);
        }
      }

      if closing_quote_index == 0 {
        lex_error("Expected a closing quote to end a string literal in JSON parsing!", line, column + runner.count - 1);
      }

      string_literal := slice(runner, 0, closing_quote_index + 1);
      column += string_literal.count;
      array_add(*result, Token.{.STRING_LITERAL, string_literal, line, column});
      runner = slice(runner, string_literal.count);
    }
    else if is_digit(runner[0]) || runner[0] == #char "-" {
      literal_count := 0;

      count_numeral :: (str: string, start: int) -> int {
        digit_count := 1; // Assume first character is validated already (may have been `-`)
        for :by_code_point slice(str, start + 1) {
          if !is_digit(it) {
            break;
          }
          digit_count += 1;
        }
        return digit_count;
      }

      whole_part_count := count_numeral(runner, literal_count); // First character could be `-`, which is okay

      if whole_part_count == 1 && runner[0] == #char "-" {
        lex_error("Expected a number literal, but we got just a negative sign.", line, column);
      }

      literal_count += whole_part_count;

      if literal_count < runner.count && runner[literal_count] == #char "." {
        literal_count += 1;

        if literal_count >= runner.count || !is_digit(runner[literal_count]) {
          lex_error("Number literals cannot end with a decimal point.", line, column + literal_count);
        }

        fractional_part_count := count_numeral(runner, literal_count);
        literal_count += fractional_part_count;
      }

      if literal_count < runner.count && runner[literal_count] == #char "e" {
        literal_count += 1;

        if literal_count >= runner.count || !(is_digit(runner[literal_count]) || runner[literal_count] == #char "-") {
          lex_error("Expected an integer after exponent marker `e` was specified in number literal.", line, column + literal_count);
        }

        exponent_part_count := count_numeral(runner, literal_count); // First character could be `-`, which is okay

        if exponent_part_count == 1 && runner[literal_count] == #char "-" {
          lex_error("Expected an integer exponent in number literal, but we got just a negative sign.", line, column + literal_count);
        }
        literal_count += exponent_part_count;
      }

      column += literal_count;
      array_add(*result, Token.{.NUMBER_LITERAL, slice(runner, 0, literal_count), line, column});
      runner = slice(runner, literal_count);
    }
    else if runner[0] >= #char "a" && runner[0] <= #char "z" {
      first_non_letter_index := runner.count;

      for :by_code_point runner {
        if !(runner[0] >= #char "a" && runner[0] <= #char "z") {
          first_non_letter_index = it_index;
          break;
        }
      }

      word := slice(runner, 0, first_non_letter_index);
      column += word.count;
      if word == "null" {
        array_add(*result, Token.{.NULL_LITERAL, word, line, column});
      }
      else if word == "true" || word == "false" {
        array_add(*result, Token.{.BOOLEAN_LITERAL, word, line, column});
      }
      else {
        lex_error("Unexpected word found: %", line, column, word);
      }

      runner = slice(runner, word.count);
    }
    else if char_in_string(runner[0], WHITESPACE_CHARS) {
      while runner.count && char_in_string(runner[0], WHITESPACE_CHARS) {
        if runner[0] == #char "\n" {
          column = 1;
          line += 1;
        }
        else {
          column += 1;
        }
        runner = slice(runner, 1);
      }
    }
    else {
      lex_error("Unexpected character found: %", line, column, slice(runner, 0, 1));
    }
  }

  return result, true;
}

//////////////////////////////

parse_error :: (return_val: $T, $format: string, args: ..Any) #expand {
  log((#run tprint("JSON parse error (line %%, column %%): %", format)), ..args, flags = .ERROR);
  `return return_val, `tokens, false;
}

advance :: (tokens: *[] Token) #expand {
  if !tokens.count {
    log("JSON parse error: Unexpectedly hit the end of the file! Unclosed from line %, column %", `eof_line, `eof_column, flags = .ERROR);
    `return `error_return, .[], false;
  }
  <<tokens = array_view(<<tokens, 1);
}

expect_more :: (tokens: [] Token) #expand {
  if !tokens.count {
    log("JSON parse error: Unexpectedly hit the end of the file! Unclosed from line %, column %", `eof_line, `eof_column, flags = .ERROR);
    `return `error_return, .[], false;
  }
}

parse_json_string :: (text: string) -> (json: Json, success: bool) {
  result: Json;

  tokens, lex_success := lex_json_string(text);
  if !lex_success return result, false;

  root, new_tokens, success := parse_json_value(tokens);

  if success && new_tokens.count > 0 {
    log("JSON parse error (line %, column %): Junk content still found after parsing!", new_tokens[0].line, new_tokens[0].column, flags = .ERROR);
    return result, false;
  }

  result.root = root;

  return result, success;
}

parse_json_value :: (tokens: [] Token) -> (val: Json_Val, new_tokens: [] Token, success: bool) {
  error_return :: Json_Val.{};
  eof_line, eof_column := tokens[0].line, tokens[0].column;

  if tokens.count == 0 {
    parse_error(Json_Val.{}, "Expected JSON value, but there's nothing left to parse!", 0, 0);
  }

  result: Json_Val;
  new_tokens := tokens;

  if tokens[0].text == "{" {
    object, object_tokens, object_success := parse_json_object(tokens);
    new_tokens = object_tokens;
    set(*result, object);
    return result, new_tokens, object_success;
  }
  else if tokens[0].text == "[" {
    array, array_tokens, array_success := parse_json_array(tokens);
    new_tokens = array_tokens;
    set(*result, array);
    return result, array_tokens, array_success;
  }

  if tokens[0].type == .PUNCTUATION {
    parse_error(Json_Val.{}, "Expected JSON value, but found `%`", tokens[0].line, tokens[0].column, tokens[0].text);
  }

  // must be a literal...
  literal := New(Json_Literal);
  literal.value = tokens[0].text;
  if #complete tokens[0].type == {
    case .STRING_LITERAL;
      literal.kind = .STRING;
      literal.value = slice(literal.value, 1, literal.value.count-2); // Trim off surrounding quotes
    case .NUMBER_LITERAL;
      literal.kind = .NUMBER;
    case .BOOLEAN_LITERAL;
      literal.kind = .BOOLEAN;
    case .NULL_LITERAL;
      literal.kind = .NULL;

    case .PUNCTUATION;
      assert(false); // already handled above
  }

  set(*result, literal);

  advance(*new_tokens);
  return result, new_tokens, true;
}

parse_json_object :: (tokens: [] Token) -> (object: *Json_Object, new_tokens: [] Token, success: bool) {
  // Assumed to have already seen the "{" by the time we get in here
  error_return :: cast(*Json_Object)null;
  eof_line, eof_column := tokens[0].line, tokens[0].column;

  new_tokens := tokens;
  advance(*new_tokens);

  if new_tokens.count == 0 {
    parse_error(cast(*Json_Object)null, "Expected the body of a JSON object, but there's nothing left to parse!", 0, 0);
  }

  result := New(Json_Object);
  init(*result.fields);

  while new_tokens.count && new_tokens[0].text != "}" {
    if new_tokens[0].type != .STRING_LITERAL {
      parse_error(cast(*Json_Object)null, "Expected a string literal as the field name for an object, but instead found `%`!", new_tokens[0].line, new_tokens[0].column, new_tokens[0].text);
    }

    field_name := new_tokens[0].text;
    field_name = slice(field_name, 1, field_name.count-2); // Trim off surrounding quotes
    advance(*new_tokens);

    if new_tokens[0].text != ":" {
      parse_error(cast(*Json_Object)null, "Expected `:` after object field name, but instead found `%`!", new_tokens[0].line, new_tokens[0].column, new_tokens[0].text);
    }
    advance(*new_tokens);

    field_value, field_tokens, field_success := parse_json_value(new_tokens);
    if !field_success return result, field_tokens, false;
    new_tokens = field_tokens;
    expect_more(new_tokens);

    // Note that this logic allows trailing commas, which I think isn't standards compliant (?), but I don't care!
    if new_tokens[0].text != "," && new_tokens[0].text != "}" {
      parse_error(cast(*Json_Object)null, "Expected `,` or `}` after object field value, but instead found `%`!", new_tokens[0].line, new_tokens[0].column, new_tokens[0].text);
    }
    if new_tokens[0].text == ","  advance(*new_tokens);

    table_add(*result.fields, field_name, field_value);
  }
  advance(*new_tokens);

  return result, new_tokens, true;
}

parse_json_array :: (tokens: [] Token) -> (array: *Json_Array, new_tokens: [] Token, success: bool) {
  // Assumed to have already seen the "[" by the time we get in here
  error_return :: cast(*Json_Array)null;
  eof_line, eof_column := tokens[0].line, tokens[0].column;

  new_tokens := tokens;
  advance(*new_tokens);

  if new_tokens.count == 0 {
    parse_error(cast(*Json_Array)null, "Expected the body of an array, but there's nothing left to parse!", 0, 0);
  }

  result := New(Json_Array);
  members: [..] Json_Val;

  while new_tokens.count && new_tokens[0].text != "]" {
    // @TODO: need to handle end-of-file errors here
    member_value, member_tokens, member_success := parse_json_value(new_tokens);
    if !member_success return result, member_tokens, false;
    new_tokens = member_tokens;
    expect_more(new_tokens);
    array_add(*members, member_value);

    // Note that this logic allows trailing commas, which I think isn't standards compliant (?), but I don't care!
    if new_tokens[0].text != "," && new_tokens[0].text != "]" {
      parse_error(cast(*Json_Array)null, "Expected `,` or `]` after array member, but instead found `%`!", new_tokens[0].line, new_tokens[0].column, new_tokens[0].text);
    }
    if new_tokens[0].text == ","  advance(*new_tokens);
  }
  advance(*new_tokens);

  result.array = members;
  return result, new_tokens, true;
}

free_json :: (json: *Json) {

}

usage_error :: (return_val: $T, $format: string, args: ..Any) #expand {
  log((#run tprint("JSON error: %", format)), ..args, flags = .ERROR);
  `return return_val, false;
}

get :: inline (json: Json, path: ..Any) -> (result: Json_Val, success: bool) {
  result, success := get(json.root, ..path);
  return result, success;
}

get :: (val: Json_Val, path: ..Any) -> (result: Json_Val, success: bool) {
  runner := val;
  for path {
    if it.type == type_info(int) {
      array := isa(runner, *Json_Array);
      if array == null {
        usage_error(Json_Val.{}, "Tried indexing into an array, but this JSON value is not an array!");
      }

      index := << cast(*int) it.value_pointer;
      if index < 0 || index >= (<<array).array.count {
        usage_error(Json_Val.{}, "Index % is outside the bounds of this JSON array!", index);
      }

      runner = (<<array).array[index];
    }
    else if it.type == type_info(string) {
      object := isa(runner, *Json_Object);
      if object == null {
        usage_error(Json_Val.{}, "Tried looking up into an object, but this JSON value is not an object!");
      }

      index := << cast(*string) it.value_pointer;
      field_value, success := table_find(*(<<object).fields, index);

      if !success {
        usage_error(Json_Val.{}, "Tried looking up into an object, but the key given (\"%\") wasn't found!", field_value);
      }

      runner = field_value;
    }
    else {
      usage_error(Json_Val.{}, "Received a path argument of an invalid type!");
    }
  }

  return runner, true;
}

read :: (val: Json_Val, $T: Type) -> (result: T, success: bool) {
  Json_Val.match_one(*val,
    *Json_Literal, #code {
      result, success := read(<<it, `T);
      `return result, success;
    },
    /* else */     #code {
      usage_error(default_value(`T), "Cannot read a value out of this JSON because it's not a primitive!");
    }
  );
}

read :: (val: Json_Literal, $T: Type) -> (result: T, success: bool) {
  #if #run type_info(T).type == .INTEGER {
    if val.kind != .NUMBER {
      usage_error(default_value(T), "Tried to read an integer from the JSON, but this value isn't a number!");
    }
    result, success := string_to_int(val.value, T = T);
    if !success {
      usage_error(default_value(T), "Failed to convert JSON value to an integer: `%`", val.value);
    }
    return result, success;
  }
  else #if T == float32 {
    if val.kind != .NUMBER {
      usage_error(default_value(T), "Tried to read a float32 from the JSON, but this value isn't a number!");
    }
    result, success := string_to_float(val.value);
    if !success {
      usage_error(default_value(T), "Failed to convert JSON value to an float32: `%`", val.value);
    }
    return result, success;
  }
  else #if T == float64 {
    if val.kind != .NUMBER {
      usage_error(default_value(T), "Tried to read a float64 from the JSON, but this value isn't a number!");
    }
    result, success := string_to_float64(val.value);
    if !success {
      usage_error(default_value(T), "Failed to convert JSON value to an float64: `%`", val.value);
    }
    return result, success;
  }
  else #if T == string {
    if val.kind != .STRING {
      usage_error(default_value(T), "Tried to read a string from the JSON, but this value isn't a string!");
    }
    return val.value, true;
  }
  else #if T == bool {
    if val.kind != .STRING {
      usage_error(default_value(T), "Tried to read a bool from the JSON, but this value isn't a bool!");
    }
    // Going to assume the lexer and parser are working correctly here...
    return val.value == "true", true;
  }
  else {
    #assert false "The type passed in is not supported!";
  }
}

print_json :: (json: Json) {
  print_json_value(json.root);
  print("\n");
}

print_json_object :: (object: Json_Object, level: int = 0) {
  print("{\n");
  for object.fields {
    for 1..level+1  print("  ");
    print("\"%\": ", it_index);
    print_json_value(it, level+1);
    print(",\n");
  }

  for 1..level  print("  ");
  print("}");
}

print_json_array :: (array: Json_Array, level: int = 0) {
  print("[\n");
  for array.array {
    for 1..level+1  print("  ");
    print_json_value(it, level+1);
    print(",\n");
  }

  for 1..level  print("  ");
  print("]");
}

print_json_value :: (value: Json_Val, level: int = 0) {
  Json_Val.match(*value,
    *Json_Object,  #code { print_json_object(<<it, `level); },
    *Json_Array,   #code { print_json_array (<<it, `level); },
    *Json_Literal, #code {
      if (<<it).kind == .STRING {
        print("\"%\"", (<<it).value);
      }
      else {
        print((<<it).value);
      }
    },
  );
}

/* #run {
  new_context := context;
  new_context.allocator = temp;
  push_context new_context {
    auto_release_temp();

    json, success := parse_json_string("{ \"wee\" : \"woo\", \"fee\": [3, 4] }");
    if success {
      print_json(json);

      num := get(json, "fee", 1);
      print("value: %\n", read(num, int));
    }
  }
} */


////////////////////////

slice :: (str: string, index: int, count: int) -> string {
  assert(index >= 0, "index = %", index);
  assert(count >= 0, "count = %", count);
  if index >= str.count {
    empty: string;
    return empty;
  }

  if index + count > str.count {
    count = str.count - index;
  }

  result: string = ---;
  result.data  = str.data + index;
  result.count = count;
  return result;
}

slice :: (str: string, index: int) -> string {
  assert(index >= 0, "index = %", index);
  if index >= str.count {
    empty: string;
    return empty;
  }

  result: string = ---;
  result.data  = str.data  + index;
  result.count = str.count - index;
  return result;
}

// Iterate over a string by code point (i.e. byte-by-byte).
by_code_point :: (str: *string, body: Code, flags: For_Flags) #expand {
  array: [] u8 = ---;
  array.data  = cast(*u8) str.data;
  array.count = str.count;

  for <=cast(bool)(flags & .REVERSE), *=cast(bool)(flags & .POINTER) `it, `it_index: array {
    #insert body;
  }
}

default_value :: inline ($T: Type) -> T {
  result: T;
  return result;
}
