Test_Mode :: enum u32 {
  UNINITIALIZED;
  TESTING;
  COMPLETED;
  ERROR;
}

Repetition_Test_Results :: struct {
  test_count: u64;
  total_time: u64;
  max_time:   u64;
  min_time:   u64;
}

Repetition_Tester :: struct {
  target_processed_byte_count:    u64;
  cpu_timer_freq:                 u64;
  try_for_time:                   u64;
  tests_started_at:               u64;
  mode:                           Test_Mode;
  print_new_minimums:             bool;
  open_block_count:               u32;
  close_block_count:              u32;
  time_accumulated_on_this_test:  u64;
  bytes_accumulated_on_this_test: u64;

  results:                        Repetition_Test_Results;
}

is_testing :: (tester: *Repetition_Tester) -> bool {
  if tester.mode == .TESTING {
    current_time := rdtsc();

    if tester.open_block_count {
      if tester.open_block_count != tester.close_block_count {
        error(tester, "Unbalanced begin_time/end_time");
      }

      if tester.bytes_accumulated_on_this_test != tester.target_processed_byte_count {
        error(tester, "Processed byte count mismatch");
      }

      if tester.mode == .TESTING {
        results := *tester.results;

        elapsed_time := tester.time_accumulated_on_this_test;
        results.test_count += 1;
        results.total_time += elapsed_time;

        if results.max_time < elapsed_time {
          results.max_time = elapsed_time;
        }

        if results.min_time > elapsed_time {
          results.min_time = elapsed_time;

          // Whenever we get a new minimum time, we reset the clock to the full trial time
          tester.tests_started_at = current_time;

          if tester.print_new_minimums {
            print_time("Min", results.min_time, tester.cpu_timer_freq, tester.bytes_accumulated_on_this_test);
            print("               \r");
          }
        }

        tester.open_block_count               = 0;
        tester.close_block_count              = 0;
        tester.time_accumulated_on_this_test  = 0;
        tester.bytes_accumulated_on_this_test = 0;
      }
    }

    if current_time - tester.tests_started_at > tester.try_for_time {
      tester.mode = .COMPLETED;

      print("                                                                   \r");
      print_results(tester.results, tester.cpu_timer_freq, tester.target_processed_byte_count);
    }
  }

  return tester.mode == .TESTING;
}

new_test_wave :: (tester: *Repetition_Tester, target_processed_byte_count: u64, cpu_timer_freq: u64, seconds_to_try: u32 = 5) {
  if tester.mode == .UNINITIALIZED {
    tester.mode                        = .TESTING;
    tester.target_processed_byte_count = target_processed_byte_count;
    tester.cpu_timer_freq              = cpu_timer_freq;
    tester.print_new_minimums          = true;
    tester.results.min_time            = U64_MAX;
  }
  else if tester.mode == .COMPLETED {
    tester.mode = .TESTING;
    if tester.target_processed_byte_count != target_processed_byte_count {
      error(tester, "target_processed_byte_count changed");
    }

    if (tester.cpu_timer_freq != cpu_timer_freq) {
      error(tester, "cpu_timer_freq changed");
    }
  }

  tester.try_for_time     = seconds_to_try * cpu_timer_freq;
  tester.tests_started_at = rdtsc();
}

begin_time :: (tester: *Repetition_Tester) {
  tester.open_block_count += 1;
  tester.time_accumulated_on_this_test -= rdtsc();
}

end_time :: (tester: *Repetition_Tester) {
  tester.close_block_count += 1;
  tester.time_accumulated_on_this_test += rdtsc();
}

count_bytes :: (tester: *Repetition_Tester, byte_count: u64) {
  tester.bytes_accumulated_on_this_test += byte_count;
}

seconds_from_cpu_time :: (cpu_time: float64, cpu_timer_freq: u64) -> float64 {
  result: float64 = 0;

  if cpu_timer_freq {
    result = cpu_time / cast(float64) (cpu_timer_freq);
  }

  return result;
}

print_time :: (label: string, cpu_time: float64, cpu_timer_freq: u64, byte_count: u64) {
  print("%: %", label, cast(u64) cpu_time);

  if cpu_timer_freq {
    seconds := seconds_from_cpu_time(cpu_time, cpu_timer_freq);
    print(" (% ms)", 1000 * seconds);

    if byte_count {
      gigbayte: float64 = 1024*1024*1024;
      best_bandwidth: float64 = byte_count / (gigbayte * seconds);
      print(" % GB/s", best_bandwidth);
    }
  }
}

print_time :: (label: string, cpu_time: u64, cpu_timer_freq: u64, byte_count: u64) {
  print_time(label, cast(float64) cpu_time, cpu_timer_freq, byte_count);
}

print_results :: (results: Repetition_Test_Results, cpu_timer_freq: u64, byte_count: u64) {
  print_time("Min", results.min_time, cpu_timer_freq, byte_count);
  print("\n");

  print_time("Max", results.max_time, cpu_timer_freq, byte_count);
  print("\n");

  if results.test_count {
    print_time("Avg", (cast(float64) results.total_time) / results.test_count, cpu_timer_freq, byte_count);
    print("\n");
  }
}

error :: (tester: *Repetition_Tester, msg: string) {
  print("%\n", msg);
  tester.mode = .ERROR;
}

#scope_file

#import "Machine_X64";
#import "Basic";
#import "Math";
