// Meant to be compile-time only! Incremented on every new timer macro call.
ct_timer_count := 1;

Timer_Data :: struct {
  elapsed_exclusive: u64;  // Excludes time spent in children
  elapsed_inclusive: u64;  // Includes time spent in children
  hit_count: u64;
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

time_function :: () #expand {
  this_timer_index :: #run unique_timer_index(#procedure_name());

  parent_index          := g_profiler_parent;
  g_profiler_parent      = this_timer_index;
  timer_data            := *g_timer_info[this_timer_index];
  old_elapsed_inclusive := timer_data.elapsed_inclusive;
  timer_data.name        = #procedure_name();
  start                 := rdtsc();

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

time_block :: ($name: string) #expand {
  this_timer_index :: #run unique_timer_index(name);

  parent_index          := g_profiler_parent;
  g_profiler_parent      = this_timer_index;
  timer_data            := *g_timer_info[this_timer_index];
  old_elapsed_inclusive := timer_data.elapsed_inclusive;
  timer_data.name        = name;
  start                 := rdtsc();

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

  log("Timing info:");
  log("Total time: %", total_time);

  percent_sum: float64 = 0;
  for * g_timer_info {
    if !it.name.count  continue;
    percent      := (cast(float64)it.elapsed_exclusive)/total_time * 100;

    if it.elapsed_exclusive != it.elapsed_inclusive {
      percent_with_children := (cast(float64)it.elapsed_inclusive)/total_time * 100;
      log("  %[%]: % (%0%%, %0%% w/ children)", it.name, it.hit_count, it.elapsed_exclusive, percent, percent_with_children);
    }
    else {
      log("  %[%]: % (%0%%)", it.name, it.hit_count, it.elapsed_exclusive, percent);
    }

    percent_sum += percent;
  }

  log("Percent of runtime covered: %", percent_sum);
}

#scope_file

#import "Machine_X64";
#import "Basic";