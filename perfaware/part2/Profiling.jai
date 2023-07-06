// Meant to be compile-time only! Incremented on every new timer macro call.
ct_timer_count := 1;

Timer_Data :: struct {
  elapsed, elapsed_children: u64;
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
    <<it = Timer_Data.{};
  }
}

time_function :: () #expand {
  this_timer_index :: #run -> int {
    result := ct_timer_count;
    ct_timer_count += 1;
    return result;
  }

  parent_index      := g_profiler_parent;
  g_profiler_parent  = this_timer_index;
  timer_data        := *g_timer_info[this_timer_index];
  parent_data       := *g_timer_info[parent_index];
  timer_data.name    = #procedure_name();
  start             := rdtsc();

  `defer {
    elapsed                      := rdtsc() - start;
    timer_data.elapsed           += elapsed;
    parent_data.elapsed_children += elapsed;
    g_profiler_parent             = parent_index;
    timer_data.hit_count         += 1;
  }
}

time_block :: ($name: string) #expand {
  this_timer_index :: #run -> int {
    result := ct_timer_count;
    ct_timer_count += 1;
    return result;
  }

  parent_index      := g_profiler_parent;
  g_profiler_parent  = this_timer_index;
  timer_data        := *g_timer_info[this_timer_index];
  parent_data       := *g_timer_info[parent_index];
  timer_data.name    = name;
  start             := rdtsc();

  `defer {
    elapsed                      := rdtsc() - start;
    timer_data.elapsed           += elapsed;
    parent_data.elapsed_children += elapsed;
    g_profiler_parent             = parent_index;
    timer_data.hit_count         += 1;
  }
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

    if it.elapsed_children > 0 {
      percent_with_children := (cast(float64)it.elapsed)/total_time * 100;
      log("  %: % (%0%%, %0%% w/ children)", it.name, real_elapsed, percent, percent_with_children);
    }
    else {
      log("  %: % (%0%%)", it.name, real_elapsed, percent);
    }

    percent_sum += percent;
  }

  log("Percent of runtime covered: %", percent_sum);
}

#scope_file

#import "Machine_X64";
#import "Basic";