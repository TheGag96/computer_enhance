#import "Basic";
#import "File";

#load "Haversine_Formula.jai";
#load "Json.jai";

Point_Pair :: struct {
  x0, y0, x1, y1: float64;
}

main :: () {
  args := get_command_line_arguments();

  if args.count < 2 || args.count > 3 {
    log("Usage: Haversine_Processor haversine_input.json [answers.f64]", flags = .ERROR);
    exit(1);
  }

  json_filename := args[1];
  answers_filename := ifx args.count == 3 then args[2] else "";

  json, success := parse_json_string(read_entire_file(json_filename));
  if !success {
    log("Failed to parse JSON file!", flags = .ERROR);
    exit(1);
  }

  pairs := get(*json, "pairs");
  pairs_array := isa(pairs, *Json_Array);

  extracted_pairs: [..] Point_Pair;
  array_resize(*extracted_pairs, (<<pairs_array).array.count, initialize = false);

  for 0..(<<pairs_array).array.count-1 {
    pair := get(pairs, it);

    extracted_pairs[it].x0 = read(get(pair, "x0"), float64);
    extracted_pairs[it].y0 = read(get(pair, "y0"), float64);
    extracted_pairs[it].x1 = read(get(pair, "x1"), float64);
    extracted_pairs[it].y1 = read(get(pair, "y1"), float64);
  }

  print("%\n", extracted_pairs);
}

