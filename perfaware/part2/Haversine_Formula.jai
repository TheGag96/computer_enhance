/* ========================================================================

   (C) Copyright 2023 by Molly Rocket, Inc., All Rights Reserved.
   
   This software is provided 'as-is', without any express or implied
   warranty. In no event will the authors be held liable for any damages
   arising from the use of this software.
   
   Please see https://computerenhance.com for more information
   
   ======================================================================== */

/* ========================================================================
   LISTING 65
   ======================================================================== */

#import "Math";

Point_Pair :: struct {
  x0, y0, x1, y1: float64;
}

square :: (a: float64) -> float64 {
  result: float64 = (a*a);
  return result;
}

radians_from_degrees :: (degrees: float64) -> float64 {
  result: float64 = 0.01745329251994329577 * degrees;
  return result;
}

// NOTE(casey): earth_radius is generally expected to be 6372.8
EARTH_RADIUS :: 6372.8;

reference_haversine :: (using pair: Point_Pair, earth_radius: float64) -> float64 {
  /* NOTE(casey): This is not meant to be a "good" way to calculate the Haversine distance.
     Instead, it attempts to follow, as closely as possible, the formula used in the real-world
     question on which these homework exercises are loosely based.
  */

  lat1: float64 = y0;
  lat2: float64 = y1;
  lon1: float64 = x0;
  lon2: float64 = x1;

  dLat: float64 = radians_from_degrees(lat2 - lat1);
  dLon: float64 = radians_from_degrees(lon2 - lon1);
  lat1 = radians_from_degrees(lat1);
  lat2 = radians_from_degrees(lat2);

  a: float64 = square(my_sin(dLat/2.0)) + my_cos(lat1)*my_cos(lat2)*square(my_sin(dLon/2));
  c: float64 = 2.0*my_asin(my_sqrt(a));

  result: float64 = earth_radius * c;

  return result;
}

Interval :: struct {
  min, max: float64 = FLOAT64_INFINITY, -FLOAT64_INFINITY;
}

update_extremes :: (interval: *Interval, value: float64) {
  if value < interval.min  interval.min = value;
  if value > interval.max  interval.max = value;
}

Math_Func :: enum s32 {
  SIN;
  COS;
  ASIN;
  SQRT;
  NUM_FUNCS;
}

Telemetry :: struct {
  domain: Interval;
  range: Interval;
  impl_difference: Interval;
  diff_count: int;
}


g_telemetry: [Math_Func.NUM_FUNCS] Telemetry;

trig_telemetry :: ($func: (v: float64) -> float64, $other_func: (v: float64) -> float64 #c_call, $trig: Math_Func, x: float64) -> float64 {
  result := func(x);
  libc_result := other_func(x);
  update_extremes(*g_telemetry[trig].domain, x);
  update_extremes(*g_telemetry[trig].range, result);
  update_extremes(*g_telemetry[trig].impl_difference, abs(libc_result - result));
  if result != libc_result  g_telemetry[trig].diff_count += 1;
  return result;
}

log_telemetry :: () {
  scientific :: (x: float64) -> FormatFloat #expand {
    return FormatFloat.{value = x, mode = .SCIENTIFIC};
  }

  for g_telemetry {
    log("Function %:", cast(Math_Func) it_index);
    log("  Domain:     min = %, max = %", it.domain.min,          it.domain.max);
    log("  Range:      min = %, max = %", it.range.min,           it.range.max);
    log("  Impl Diff:  min = %, max = %", scientific(it.impl_difference.min), scientific(it.impl_difference.max));
  }
}

my_sin  :: #bake_arguments trig_telemetry(func = #procedure_of_call sin( cast(float64) 0), other_func = libc_sin,  trig = .SIN);
my_cos  :: #bake_arguments trig_telemetry(func = #procedure_of_call cos( cast(float64) 0), other_func = libc_cos,  trig = .COS);
my_asin :: #bake_arguments trig_telemetry(func = #procedure_of_call asin(cast(float64) 0), other_func = libc_asin, trig = .ASIN);
my_sqrt :: #bake_arguments trig_telemetry(func = #procedure_of_call sqrt(cast(float64) 0), other_func = libc_sqrt, trig = .SQRT);

libc_sin :: (x: float64) -> float64 #foreign libc "sin";
libc_cos :: (x: float64) -> float64 #foreign libc "cos";
libc_asin :: (x: float64) -> float64 #foreign libc "asin";
libc_sqrt :: (x: float64) -> float64 #foreign libc "sqrt";

#if OS == .WINDOWS {
  libc :: #library,system "msvcrt";
}
else {
  libc :: #library,system "libm";
}