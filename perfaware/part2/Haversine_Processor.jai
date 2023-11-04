#import "Basic";
#import "File";

#load "Haversine_Formula.jai";
#load "Json.jai";
#load "Profiling.jai";

main :: () {
  begin_profile();

  json_filename, answers_filename: string;

  {
    time_block("Startup");

    args := get_command_line_arguments();

    if args.count < 2 || args.count > 3 {
      log("Usage: Haversine_Processor haversine_input.json [answers.f64]", flags = .ERROR);
      exit(1);
    }

    json_filename    = args[1];
    answers_filename = ifx args.count == 3 then args[2] else "";
  }

  json_text: string;
  {
    time_block("Read");
    json_text = read_entire_file(json_filename);
  }

  json: Json;
  success: bool;
  {
    time_block("Parse");
    json, success = parse_json_string(json_text);
    if !success {
      log("Failed to parse JSON file!", flags = .ERROR);
      exit(1);
    }
  }

  extracted_pairs: [..] Point_Pair;
  {
    time_block("Read");

    pairs := get(*json, "pairs");
    pairs_array := isa(pairs, *Json_Array);
    array_resize(*extracted_pairs, pairs_array.*.array.count, initialize = false);

    for pairs_array.*.array {
      extracted_pairs[it_index].x0 = read(get(it, "x0"), float64);
      extracted_pairs[it_index].y0 = read(get(it, "y0"), float64);
      extracted_pairs[it_index].x1 = read(get(it, "x1"), float64);
      extracted_pairs[it_index].y1 = read(get(it, "y1"), float64);
    }
  }


  sum: float64;
  {
    time_block("Sum", byte_count = byte_count(extracted_pairs));

    for extracted_pairs {
      sum += reference_haversine(it, EARTH_RADIUS);
    }
  }

  {
    time_block("MiscOutput");

    log("Input size: %", json_text.count);
    log("Pair count: %", extracted_pairs.count);
    log("Haversine sum: %", sum);

    if answers_filename.count {
      answer_bytes := read_entire_file(answers_filename);
      assert(answer_bytes.count == size_of(float64));
      answer := (cast(*float64) answer_bytes.data).*;

      log("\nValidation:");
      log("Reference sum: %", answer);
      log("Difference: %",  abs(sum-answer));
    }
  }

  end_profile_and_log();
}

