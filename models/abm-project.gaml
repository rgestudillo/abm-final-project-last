/**
* Name: Simple Random Walk
* Description: Simplified model where people randomly walk on roads
*/
 
model Simple_Random_Walk

global {
	file shapefile_roads <- file("../includes/Rouen roads.shp");
	geometry shape <- envelope(shapefile_roads);
	graph road_network;
	map<road,float> current_weights;
	
	init {
		create road from: shapefile_roads;
		
		// Create people and place them randomly on roads
		create people number: 200 {
			location <- any_location_in(one_of(road));
		}
		
		road_network <- as_edge_graph(road);
		current_weights <- road as_map (each::each.shape.perimeter);
	}
	
	reflex update_speeds when: every(10#cycle) {
		current_weights <- road as_map (each::each.shape.perimeter / each.speed_coeff);
		road_network <- road_network with_weights current_weights;
	}
}
 
species people skills: [moving] {
	point target;
	float speed <- 30 #km/#h;
	rgb color <- #blue;
	road target_road;
	
	init {
		// Find road125 and set it as target road
		target_road <- road first_with (each.name = "road125");
		if (target_road = nil) {
			// If road125 not found, use first road as fallback
			target_road <- first(road);
		}
	}
	
	reflex walk_to_target_road {
		// If no target, pick a location on the target road
		if (target = nil) {
			target <- any_location_in(target_road);
		} else {
			// Move towards target on target road
			do goto target: target on: road_network move_weights: current_weights recompute_path: false;
			
			// If reached target, pick a new location on the same target road
			if (target = location) {
				target <- any_location_in(target_road);
			}
		}
	}
	
	aspect default {
		draw triangle(30) rotate: heading + 90 color: color;
	}
}

species road {
	float capacity <- 1 + shape.perimeter/50;
	int nb_people <- 0 update: length(people at_distance 1);
	float speed_coeff <- 1.0 update: exp(-nb_people/capacity) min: 0.1;
	
	aspect default {
		draw shape color: #black;
	}
}

experiment main type: gui {
	float minimum_cycle_duration <- 0.02;
	output {
		display map type: 3d {
			species road refresh: false;
			species people;
		}
	}
}