// Meant to be compile-time only! Incremented on every new timer macro call.
ct_timer_count := 1;

Timer_Data :: struct {
  elapsed_exclusive: u64;  // Excludes time spent in children
  elapsed_inclusive: u64;  // Includes time spent in children
  hit_count: u64;
  processed_byte_count: u64;
  name: string;
}

MAX_TIMERS :: 100;
g_timer_info: [MAX_TIMERS] Timer_Data;
g_profiling_start_time: u64;
g_profiler_parent: int;

begin_profile :: () {
  g_profiling_start_time = rdtsc();

  for * g_timer_info {
    it.* = Timer_Data.{};
  }
}

time_function :: (byte_count: u64 = 0) #expand {
  this_timer_index :: #run unique_timer_index(#procedure_name());

  parent_index                    := g_profiler_parent;
  g_profiler_parent                = this_timer_index;
  timer_data                      := *g_timer_info[this_timer_index];
  old_elapsed_inclusive           := timer_data.elapsed_inclusive;
  timer_data.name                  = #procedure_name();
  timer_data.processed_byte_count += byte_count;
  start                           := rdtsc();

  `defer {
    end := rdtsc();
    elapsed                  := end - start;

    timer_data.elapsed_exclusive += elapsed;
    timer_data.elapsed_inclusive  = old_elapsed_inclusive + elapsed;

    // For the parent block, subtract off in place the time we spent inside the inner block.
    // This solves elapsed time being doubly counted across two timers when running one timer inside another.
    g_timer_info[parent_index].elapsed_exclusive -= elapsed;

    g_profiler_parent             = parent_index;
    timer_data.hit_count         += 1;
  }
}

time_block :: ($name: string, byte_count: u64 = 0) #expand {
  this_timer_index :: #run unique_timer_index(name);

  parent_index                    := g_profiler_parent;
  g_profiler_parent                =  this_timer_index;
  timer_data                      := *g_timer_info[this_timer_index];
  old_elapsed_inclusive           := timer_data.elapsed_inclusive;
  timer_data.name                  =  name;
  timer_data.processed_byte_count += byte_count;
  start                           := rdtsc();

  `defer {
    end := rdtsc();
    elapsed                  := end - start;

    timer_data.elapsed_exclusive += elapsed;
    timer_data.elapsed_inclusive  = old_elapsed_inclusive + elapsed;

    // For the parent block, subtract off in place the time we spent inside the inner block.
    // This solves elapsed time being doubly counted across two timers when running one timer inside another.
    g_timer_info[parent_index].elapsed_exclusive -= elapsed;

    g_profiler_parent             = parent_index;
    timer_data.hit_count         += 1;
  }
}

byte_count :: inline (thing: $T) -> u64 {
  ti_type :: #run (cast(*Type_Info) T).type;

  #if ti_type == .ARRAY || ti_type == .STRING {
    return byte_count(thing[0]) * (cast(u64) thing.count);
  }
  else #if ti_type == .POINTER {
    return byte_count(thing.*);
  }
  else {
    return xx size_of(T);
  }
}

unique_timer_index :: ($name: string) -> int {
  return #run -> int {
    result := ct_timer_count;
    ct_timer_count += 1;
    return result;
  };
}

end_profile_and_log :: () {
  profiling_end_time := rdtsc();
  total_time         := profiling_end_time - g_profiling_start_time;

  auto_release_temp();

  // Estimate CPU frequency
  cpu_freq_estimated := () -> int {
    ESTIMATION_TIME :: #run milliseconds_to_apollo(100);
    estimation_start_cycles := rdtsc();
    estimation_start_apollo := current_time_monotonic();
    while current_time_monotonic() < estimation_start_apollo + ESTIMATION_TIME {}
    estimation_end_cycles   := rdtsc();
    return cast(int) ((estimation_end_cycles - estimation_start_cycles) / to_float64_seconds(ESTIMATION_TIME));
  }();

  log("Timing info (CPU freq = % Hz):", cpu_freq_estimated);
  log("Total time: % ms (% cycles)", 1000.0*total_time/cpu_freq_estimated, total_time);

  percent_sum: float64 = 0;
  for * g_timer_info {
    if !it.name.count  continue;
    percent      := (cast(float64)it.elapsed_exclusive)/total_time * 100;

    children_part, data_part: string;

    if it.elapsed_exclusive != it.elapsed_inclusive {
      percent_with_children := (cast(float64)it.elapsed_inclusive)/total_time * 100;
      children_part = tprint(", %0%% w/ children", percent_with_children);
    }

    if it.processed_byte_count {
      seconds              := it.elapsed_inclusive    / (cast(float64) cpu_freq_estimated);
      bytes_per_second     := it.processed_byte_count / seconds;
      megabytes            := it.processed_byte_count / (cast(float64) (1024*1024));
      gigabytes_per_second := bytes_per_second        / (cast(float64) (1024*1024*1024));

      log("% % % %", seconds, bytes_per_second, megabytes, gigabytes_per_second);

      data_part = tprint(", % MB  @ % GB/s", megabytes, gigabytes_per_second);
    }

    log("  %[%]: % (%0%%%0%0)", it.name, it.hit_count, it.elapsed_exclusive, percent, children_part, data_part);

    percent_sum += percent;
  }

  log("Percent of runtime covered: %", percent_sum);
}

#scope_file

#import "Machine_X64";
#import "Basic";
