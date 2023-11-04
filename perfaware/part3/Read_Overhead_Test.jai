#load "Repetition_Testing.jai";
#import "File";
#import "Basic";

Read_Parameters :: struct {
  dest:     [] u8;
  filename: string;
}

Test_Function :: struct {
  name: string;
  func: #type (*Repetition_Tester, Read_Parameters);
}

test_functions :: Test_Function.[
  .{ name = "test_file_read", func = test_file_read }
];

main :: () {
  args := get_command_line_arguments();

  if args.count != 2 {
    print("Usage: Read_Overhead_Test filename");
    return;
  }

  filename := args[1];

  file, open_success := file_open(filename);
  file_size, length_success := file_length(file);
  file_close(*file);

  // Estimate CPU frequency
  cpu_timer_freq := () -> u64 {
    ESTIMATION_TIME :: #run milliseconds_to_apollo(100);
    estimation_start_cycles := rdtsc();
    estimation_start_apollo := current_time_monotonic();
    while current_time_monotonic() < estimation_start_apollo + ESTIMATION_TIME {}
    estimation_end_cycles   := rdtsc();
    return cast(u64) ((estimation_end_cycles - estimation_start_cycles) / to_float64_seconds(ESTIMATION_TIME));
  }();

  params := Read_Parameters.{ dest = NewArray(file_size, u8, initialized = false), filename = filename };

  if params.dest.count > 0 {
    testers: [test_functions.count] Repetition_Tester;

    while true {
      for 0..test_functions.count-1 {
        tester    := *testers[it];
        test_func := test_functions[it];

        print("\n--- %s ---\n", test_func.name);
        new_test_wave(tester, xx params.dest.count, cpu_timer_freq);
        test_func.func(tester, params);
      }
    }
  }
}

test_file_read :: (tester: *Repetition_Tester, params: Read_Parameters) {
  while is_testing(tester) {
    file, open_success := file_open(params.filename);

    if !open_success {
      error(tester, "file_open failed");
      continue;
    }

    begin_time(tester);
    read_success, total_read := file_read(file, params.dest.data, params.dest.count);
    end_time(tester);

    if read_success {
      count_bytes(tester, xx params.dest.count);
    }
    else {
      error(tester, "file_read failed");
    }

    file_close(*file);
  }
}