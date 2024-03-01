model FollowingPaths

import "./Traffic.gaml"

global {
	float step <- 5.0;
	float vehicle_speed_limit;
	string map_name <- "Centro";
	file shp_roads <- file("../includes/" + map_name + "/roads.shp");
	file shp_nodes <- file("../includes/" + map_name + "/nodes.shp");
	csv_file restaurants_csv <- csv_file("../includes/" + map_name + "/restaurants.csv", true);
	csv_file pedidos_csv <- csv_file("../includes/" + map_name + "/pedidos.csv", true);
	geometry shape <- envelope(shp_roads) + 50;
	graph road_network;
	list<point> restaurantes;
	list<point> pedidos;
	list<string>operadoras<-["Rappi","Glovo","Pedidos Ya"];
	bool rain;

	init {
		create road from: shp_roads with: [num_lanes::int(read("lanes"))] {
		// Create another road in the opposite direction
			create road {
				num_lanes <- myself.num_lanes;
				shape <- polyline(reverse(myself.shape.points));
				maxspeed <- myself.maxspeed;
				linked_road <- myself;
				myself.linked_road <- self;
			}

		}

		create intersection from: shp_nodes with: [is_traffic_signal::(read("type") = "traffic_signals")] {
			time_to_change <- 260 #s;
		}

		create restaurant from: restaurants_csv with: [lat::float(get("latitude")), lon::float(get("longitude")),nombre::string(get("location_name"))] {
			location <- to_GAMA_CRS({lon, lat}, "EPSG:4326").location;
			
			add location to: restaurantes;
		}

		create pedido from: pedidos_csv with: [lat::float(get("lat")), lon::float(get("lon"))] {
			location <- to_GAMA_CRS({lon, lat}, "EPSG:4326").location;
			add location to: pedidos;
		}

		// Create a graph representing the road network, with road lengths as weights
		map edge_weights <- road as_map (each::each.shape.perimeter);
		road_network <- as_driving_graph(road, intersection) with_weights edge_weights;

		// Initialize the traffic lights
		ask intersection {
			do initialize;
		}

		create vehicle_following_path number: 50 with: (vehicle_max_speed: vehicle_speed_limit);
	} }

species vehicle_following_path parent: base_vehicle {
	float timer <- 0.0 #minute; // Add a timer variable
	float vehicle_max_speed;
	

	init {
		
		operador<-operadoras[rnd(2)];
		vehicle_length <- 1.9 #m;
		if (rain) {
			
			max_speed <-  40 / 3600;
		} else {
			max_speed <- 50 / 3600;
		}

		max_acceleration <- 3.5;
	
	}

	reflex select_next_path when: current_path = nil {
		list<intersection> dst_nodes <- [intersection[rnd(3017)], restaurantes[rnd(8)] as intersection, pedidos[rnd(32)] as intersection];
		
		do compute_path graph: road_network nodes: dst_nodes;
	}

	reflex commute when: current_path != nil {
		do drive;
		timer <- timer + step;
	}

	reflex stop when: current_path = nil {
		int t_final <- (timer / 60) as int;
		write ("Tiempo: " + t_final + " minutos");
		do die;
	}

}

experiment city_rain type: gui {
	parameter var: rain init: false;

	output synchronized: true {
		
		display map type: 2d background: rain?#green:#grey {
			species road aspect: base;
			species vehicle_following_path aspect: base;
			species intersection aspect: base;
			species restaurant aspect: base;
			species pedido aspect: solicitando;
		}

	}

}
