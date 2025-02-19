#import "Basic";
#import "Random";

LATITUDE_MIN  ::  -90.0;
LATITUDE_MAX  ::   90.0;
LONGITUDE_MIN :: -180.0;
LONGITUDE_MAX ::  180.0;

NUM_CLUSTERS :: 5;

CLUSTER_RADIUS_MIN :: 10.0;
CLUSTER_RADIUS_MAX :: 60.0;

main :: () {
  args := get_command_line_arguments();

  if args.count != 3 {
    log("Usage: generate [random seed] [number of coordinate pairs to generate]", flags = .ERROR);
    exit(1);
  }

  seed_val, seed_val_valid := string_to_int(args[1], T = u64);
  if !seed_val_valid {
    log("Argument for random seed wasn't a number!", flags = .ERROR);
    exit(1);
  }

  num_pairs, num_pairs_valid := string_to_int(args[2]);
  if !num_pairs_valid {
    log("Argument for number of coordinate pairs wasn't a number!", flags = .ERROR);
    exit(1);
  }

  // random_seed(current_time_monotonic().low);
  random_seed(ifx seed_val == 0 then current_time_monotonic().low else seed_val);


  log("{\"pairs\": [");

  for 1..NUM_CLUSTERS {
    cluster_lat    := random_get_within_range(LATITUDE_MIN,  LATITUDE_MAX);
    cluster_lon    := random_get_within_range(LONGITUDE_MIN, LONGITUDE_MAX);
    cluster_radius := random_get_within_range(CLUSTER_RADIUS_MIN, CLUSTER_RADIUS_MAX);
    num_in_cluster := num_pairs / NUM_CLUSTERS;

    if it == NUM_CLUSTERS {
      num_in_cluster += num_pairs % NUM_CLUSTERS;
    }

    for 1..num_in_cluster {
      random_point_on_sphere :: (center_lat: float, center_lon: float, radius: float) -> x: float, y: float {
        x := random_get_within_range(center_lon-radius, center_lon+radius);
        y := random_get_within_range(center_lat-radius, center_lat+radius);

        if y < LATITUDE_MIN   y += (LATITUDE_MAX  - LATITUDE_MIN);
        if y > LATITUDE_MAX   y -= (LATITUDE_MAX  - LATITUDE_MIN);
        if x < LONGITUDE_MIN  x += (LONGITUDE_MAX - LONGITUDE_MIN);
        if x > LONGITUDE_MAX  x -= (LONGITUDE_MAX - LONGITUDE_MIN);

        return x, y;
      }

      x0, y0 := random_point_on_sphere(cluster_lat, cluster_lon, cluster_radius);
      x1, y1 := random_point_on_sphere(cluster_lat, cluster_lon, cluster_radius);

      log("  { \"x0\": %, \"y0\": %, \"x1\": %, \"y1\": % }, ", x0, y0, x1, y1);
    }

  }

  log("]}");
}