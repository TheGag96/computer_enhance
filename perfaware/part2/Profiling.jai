// Meant to be compile-time only! Incremented on every new timer macro call.
ct_timer_count := 0;

Timer_Data :: struct {
  start, delta: u64;
  name: string;
}

MAX_TIMERS :: 100;
g_timer_info: [MAX_TIMERS] Timer_Data;
g_profiling_start_time: u64;

begin_profile :: () {
  g_profiling_start_time = rdtsc();
}

time_function :: () #expand {
  this_timer_index :: #run -> int {
    result := ct_timer_count;
    ct_timer_count += 1;
    return result;
  }

  g_timer_info[this_timer_index].start        = rdtsc();
  g_timer_info[this_timer_index].name         = #procedure_name();
  `defer g_timer_info[this_timer_index].delta = rdtsc() - g_timer_info[this_timer_index].start;
}

time_block :: ($name: string) #expand {
  this_timer_index :: #run -> int {
    result := ct_timer_count;
    ct_timer_count += 1;
    return result;
  }

  g_timer_info[this_timer_index].start        = rdtsc();
  g_timer_info[this_timer_index].name         = name;
  `defer g_timer_info[this_timer_index].delta = rdtsc() - g_timer_info[this_timer_index].start;
}

end_profile_and_log :: () {
  profiling_end_time := rdtsc();
  total_time         := profiling_end_time - g_profiling_start_time;

  log("Timing info:");
  log("Total time: %", total_time);

  percent_sum: float64 = 0;
  for * g_timer_info {
    if !it.name.count  continue;
    delta := ifx it.delta then it.delta else profiling_end_time - it.start;
    percent := (cast(float64)delta)/total_time * 100;
    log("  %: % (%0%%)", it.name, delta, percent);
    percent_sum += percent;
  }

  log("Percent of runtime covered: %", percent_sum);
}

#scope_file

#import "Machine_X64";
#import "Basic";