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

  a: float64 = square(sin(dLat/2.0)) + cos(lat1)*cos(lat2)*square(sin(dLon/2));
  c: float64 = 2.0*asin(sqrt(a));

  result: float64 = earth_radius * c;

  return result;
}
