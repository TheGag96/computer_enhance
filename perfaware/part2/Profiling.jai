// Meant to be compile-time only! Incremented on every new timer macro call.
ct_timer_count := 1;

Timer_Data :: struct {
  elapsed, elapsed_children, elapsed_at_root: u64;
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

  parent_index        := g_profiler_parent;
  g_profiler_parent    = this_timer_index;
  timer_data          := *g_timer_info[this_timer_index];
  old_elapsed_at_root := timer_data.elapsed_at_root;
  timer_data.name      = #procedure_name();
  start               := rdtsc();

  `defer {
    end := rdtsc();
    elapsed                  := end - start;

    timer_data.elapsed        += elapsed;
    timer_data.elapsed_at_root = old_elapsed_at_root + elapsed;

    // Track for the parent/outer timer being tracked how much time elapsed here so we can subtract it off later
    // This solves elapsed time being doubly counted when running one timer inside another.
    g_timer_info[parent_index].elapsed_children += elapsed;

    g_profiler_parent             = parent_index;
    timer_data.hit_count         += 1;
  }
}

time_block :: ($name: string) #expand {
  this_timer_index :: #run unique_timer_index(name);

  parent_index        := g_profiler_parent;
  g_profiler_parent    = this_timer_index;
  timer_data          := *g_timer_info[this_timer_index];
  old_elapsed_at_root := timer_data.elapsed_at_root;
  timer_data.name      = name;
  start               := rdtsc();

  `defer {
    end := rdtsc();
    elapsed                  := end - start;

    timer_data.elapsed        += elapsed;
    timer_data.elapsed_at_root = old_elapsed_at_root + elapsed;

    // Track for the parent/outer timer being tracked how much time elapsed here so we can subtract it off later
    // This solves elapsed time being doubly counted when running one timer inside another.
    g_timer_info[parent_index].elapsed_children += elapsed;

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
    real_elapsed := it.elapsed - it.elapsed_children;
    percent      := (cast(float64)real_elapsed)/total_time * 100;

    if real_elapsed != it.elapsed_at_root {
      percent_with_children := (cast(float64)it.elapsed_at_root)/total_time * 100;
      log("  %[%]: % (%0%%, %0%% w/ children)", it.name, it.hit_count, real_elapsed, percent, percent_with_children);
    }
    else {
      log("  %[%]: % (%0%%)", it.name, it.hit_count, real_elapsed, percent);
    }

    percent_sum += percent;
  }

  log("Percent of runtime covered: %", percent_sum);
}

#scope_file

#import "Machine_X64";
#import "Basic";