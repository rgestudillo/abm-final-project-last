/**
* Name: Simple Random Walk with Evacuation - Multi-Type People
* Description: People of different types (children, youth, adults, seniors, PWD) walk to road136 and get evacuated with visual status
* Features: Certain roads are permanently safe from fire and will never burn
*/

model Simple_Random_Walk_Evacuation

global {
	file shapefile_roads <- file("../includes/Rouen roads.shp");
	file shapefile_shelters <- file("../includes/lahug-house.shp");

	geometry shape <- envelope(shapefile_roads);
	graph road_network;
	graph safe_road_network; // Network excluding roads on fire
	map<road,float> current_weights;
	
	// Fire parameters
	float fire_spread_probability <- 0.25; // Balanced spread rate
	float fire_detection_distance <- 150.0;
	float fire_spread_distance <- 250.0; // Reasonable spread distance
	int initial_fire_roads <- 1; // Start with 1 fire source
	string evacuation_road_name <- "road136";
	string fire_start_road_name <- "road28"; // Fire always starts here
	float evacuation_safety_distance <- 300.0 parameter: "Evacuation Safety Distance (m)" category: "Fire Parameters" min: 100.0 max: 1000.0;
	
	// List of permanently safe roads that will never catch fire
	list<string> permanently_safe_roads <- [ 
		"road150", "road151", "road142",
		"road137", "road136", "road138", "road148", "road149", 
		"road152", "road143", "road147", "road129", 
		"road140", "road139", "road141", "road144", "road135", "road145"
	];
	
	// People type parameters - speeds in km/h
	float children_speed <- 20.0 parameter: "Children Speed (km/h)" category: "People Speeds";
	float youth_speed <- 40.0 parameter: "Youth Speed (km/h)" category: "People Speeds";
	float adults_speed <- 35.0 parameter: "Adults Speed (km/h)" category: "People Speeds";
	float seniors_speed <- 15.0 parameter: "Seniors Speed (km/h)" category: "People Speeds";
	float pwd_speed <- 10.0 parameter: "PWD Speed (km/h)" category: "People Speeds";
	
	// People type proportions
	float children_ratio <- 0.30 parameter: "Children Ratio" category: "People Distribution" min: 0.0 max: 1.0;
	float youth_ratio <- 0.20 parameter: "Youth Ratio" category: "People Distribution" min: 0.0 max: 1.0;
	float adults_ratio <- 0.44 parameter: "Adults Ratio" category: "People Distribution" min: 0.0 max: 1.0;
	float seniors_ratio <- 0.4 parameter: "Seniors Ratio" category: "People Distribution" min: 0.0 max: 1.0;
	float pwd_ratio <- 0.02 parameter: "PWD Ratio" category: "People Distribution" min: 0.0 max: 1.0;
	
	int total_people <- 500 parameter: "Total People" category: "People Distribution" min: 10 max: 1000;
	
	init {
		create road from: shapefile_roads;
		create shelter from: shapefile_shelters;
		
		// Count and display permanently safe roads
		int safe_road_count <- length(road where (each.name in permanently_safe_roads));
		write "✅ " + safe_road_count + " permanently safe roads identified";
		
		// Start fire at the designated road (road28)
		road fire_start_road <- road first_with (each.name = fire_start_road_name);
		if (fire_start_road != nil and not (fire_start_road_name in permanently_safe_roads)) {
			ask fire_start_road {
				on_fire <- true;
				write "🔥 Fire started at " + fire_start_road_name;
			}
		} else {
			if (fire_start_road_name in permanently_safe_roads) {
				write "⚠️ Warning: " + fire_start_road_name + " is a permanently safe road, starting fire randomly";
			} else {
				write "⚠️ Warning: " + fire_start_road_name + " not found, starting fire randomly";
			}
			// Fallback to random road if road28 doesn't exist or is safe
			list<road> non_evacuation_roads <- road where (each.name != evacuation_road_name and not (each.name in permanently_safe_roads));
			if (not empty(non_evacuation_roads)) {
				ask initial_fire_roads among non_evacuation_roads {
					on_fire <- true;
					write "🔥 Fire started at random road: " + name;
				}
			} else {
				write "⚠️ ERROR: No roads available for fire start!";
			}
		}
		
		// Create people of different types with their respective proportions
		list<road> safe_roads <- road where (not each.on_fire);
		if (empty(safe_roads)) {
			safe_roads <- road;
		}
		
		// Calculate actual numbers for each type
		int num_children <- int(total_people * children_ratio);
		int num_youth <- int(total_people * youth_ratio);
		int num_adults <- int(total_people * adults_ratio);
		int num_seniors <- int(total_people * seniors_ratio);
		int num_pwd <- total_people - num_children - num_youth - num_adults - num_seniors; // Remaining
		
		// Create children
		create people number: num_children {
			person_type <- "children";
			base_speed <- children_speed;
			speed <- base_speed #km/#h;
			color <- #blue;
			location <- any_location_in(one_of(safe_roads));
		}
		
		// Create youth
		create people number: num_youth {
			person_type <- "youth";
			base_speed <- youth_speed;
			speed <- base_speed #km/#h;
			color <- #cyan;
			location <- any_location_in(one_of(safe_roads));
		}
		
		// Create adults
		create people number: num_adults {
			person_type <- "adults";
			base_speed <- adults_speed;
			speed <- base_speed #km/#h;
			color <- #orange;
			location <- any_location_in(one_of(safe_roads));
		}
		
		// Create seniors
		create people number: num_seniors {
			person_type <- "seniors";
			base_speed <- seniors_speed;
			speed <- base_speed #km/#h;
			color <- #purple;
			location <- any_location_in(one_of(safe_roads));
		}
		
		// Create PWD
		create people number: num_pwd {
			person_type <- "pwd";
			base_speed <- pwd_speed;
			speed <- base_speed #km/#h;
			color <- #magenta;
			location <- any_location_in(one_of(safe_roads));
		}
		
		road_network <- as_edge_graph(road);
		do update_road_network;
	}
	
	// Update road network to exclude roads on fire
	action update_road_network {
		list<road> safe_roads <- road where (not each.on_fire);
		if (not empty(safe_roads)) {
			safe_road_network <- as_edge_graph(safe_roads);
			current_weights <- safe_roads as_map (each::each.shape.perimeter / each.speed_coeff);
			safe_road_network <- safe_road_network with_weights current_weights;
		} else {
			// Emergency fallback if all roads are on fire
			current_weights <- road as_map (each::each.shape.perimeter / each.speed_coeff);
			safe_road_network <- road_network with_weights current_weights;
		}
	}
	
	reflex spread_fire when: every(15#cycle) {
		// Get evacuation center location for safety zone calculation
		road evacuation_center <- road first_with (each.name = evacuation_road_name);
		point evacuation_location <- (evacuation_center != nil) ? evacuation_center.location : {0, 0};
		
		// Balanced fire spreading
		list<road> fire_roads <- road where each.on_fire;
		list<road> safe_roads <- road where (not each.on_fire and each.name != evacuation_road_name and not (each.name in permanently_safe_roads));
		
		// Remove roads that are within the evacuation safety zone
		if (evacuation_center != nil) {
			safe_roads <- safe_roads where (each.location distance_to evacuation_location >= evacuation_safety_distance);
		}
		
		if (not empty(fire_roads) and not empty(safe_roads)) {
			// For each fire road, try to spread to 1-2 closest safe roads
			ask fire_roads {
				// Find 2 closest safe roads to this fire (excluding permanently safe roads)
				list<road> closest_roads <- safe_roads closest_to (self.location, 2);
				
				ask closest_roads {
					float distance_to_fire <- location distance_to myself.location;
					float distance_to_evacuation <- location distance_to evacuation_location;
					
					// Double-check that this road is not in the safety zone and not permanently safe
					if (distance_to_evacuation >= evacuation_safety_distance and not (name in permanently_safe_roads)) {
						// Fire spreads to close roads with moderate probability
						if (distance_to_fire < fire_spread_distance) {
							float spread_chance <- fire_spread_probability * (1.0 - distance_to_fire / fire_spread_distance);
							
							if (flip(spread_chance)) {
								on_fire <- true;
								write "🔥 Fire spread to new road: " + name + " (distance: " + int(distance_to_fire) + "m)";
								// Remove from safe roads list so it doesn't get picked again
								safe_roads <- safe_roads - self;
							}
						}
					}
				}
			}
		}
		
		do update_road_network;
	}
	
	reflex update_speeds when: every(10#cycle) {
		do update_road_network;
	}
}

species people skills: [moving] {
	point target;
	float speed <- 30 #km/#h;
	float base_speed <- 30.0; // Base speed for this person type
	string person_type <- "adults"; // Type: children, youth, adults, seniors, pwd
	rgb color <- #blue;
	road target_road;
	string status <- "normal"; // normal, evacuating, evacuated
	bool fire_detected <- false;
	
	init {
		// Find evacuation road and set it as target road
		target_road <- road first_with (each.name = evacuation_road_name);
		if (target_road = nil) {
			// If evacuation road not found, use first road as fallback
			target_road <- first(road);
		}
	}
	
	reflex detect_fire when: status != "evacuated" {
		// Check if there's fire nearby (from roads)
		list<road> nearby_fire_roads <- road where (each.on_fire and each.location distance_to location < fire_detection_distance);
		
		if (not empty(nearby_fire_roads) and not fire_detected) {
			fire_detected <- true;
			// Start evacuating immediately if fire is detected
			if (status = "normal") {
				status <- "evacuating";
				// Change color to red but keep type distinction with brightness
				switch person_type {
					match "children" { color <- rgb(255, 100, 100); } // Light red
					match "youth" { color <- rgb(255, 0, 100); } // Red-magenta
					match "adults" { color <- rgb(255, 0, 0); } // Pure red
					match "seniors" { color <- rgb(200, 0, 0); } // Dark red
					match "pwd" { color <- rgb(150, 0, 0); } // Very dark red
				}
				// Increase evacuation speed (but maintain type-based differences)
				float panic_multiplier <- 1.3; // 30% speed increase when panicking
				switch person_type {
					match "children" { panic_multiplier <- 1.2; } // Children don't panic as much
					match "youth" { panic_multiplier <- 1.5; } // Youth can move much faster when panicking
					match "adults" { panic_multiplier <- 1.3; }
					match "seniors" { panic_multiplier <- 1.1; } // Limited panic boost for seniors
					match "pwd" { panic_multiplier <- 1.05; } // Very limited boost for PWD
				}
				speed <- base_speed * panic_multiplier #km/#h;
				target <- nil; // Reset target to force new pathfinding
			}
		}
	}
	
	reflex walk_to_target_road when: status != "evacuated" {
		// If no target, pick a location on the target road
		if (target = nil) {
			target <- any_location_in(target_road);
			if (status = "normal") {
				status <- "evacuating";
				// Change to evacuation colors but maintain type distinction
				switch person_type {
					match "children" { color <- rgb(100, 100, 255); } // Light blue
					match "youth" { color <- rgb(0, 255, 255); } // Cyan
					match "adults" { color <- rgb(255, 165, 0); } // Orange
					match "seniors" { color <- rgb(128, 0, 128); } // Purple
					match "pwd" { color <- rgb(255, 0, 255); } // Magenta
				}
			}
		} else {
			// Move towards target using safe roads only (avoiding red fire roads)
			if (safe_road_network != nil and not empty(road where (not each.on_fire))) {
				do goto target: target on: safe_road_network move_weights: current_weights recompute_path: true;
			} else {
				// Emergency movement if no safe network available
				do goto target: target;
			}
			
			// Check if reached evacuation center
			road current_road <- road closest_to location;
			if (current_road = target_road and target = location) {
				// Successfully reached evacuation center - evacuated!
				status <- "evacuated";
				color <- #green;
				target <- nil; // Stop moving
				speed <- base_speed #km/#h; // Reset to base speed
			} else if (target = location) {
				// Reached target but not on evacuation road, pick new location on target road
				target <- any_location_in(target_road);
			}
		}
	}
	
	aspect default {
		// Different shapes for different person types
		switch person_type {
			match "children" { 
				draw triangle(20) rotate: heading + 90 color: color;
			}
			match "youth" { 
				draw triangle(30) rotate: heading + 90 color: color;
			}
			match "adults" { 
				draw triangle(35) rotate: heading + 90 color: color;
			}
			match "seniors" { 
				draw circle(15) color: color;
			}
			match "pwd" { 
				draw square(20) rotate: heading + 45 color: color;
			}
			default { 
				draw triangle(30) rotate: heading + 90 color: color;
			}
		}
	}
}

species road {
	float capacity <- 1 + shape.perimeter/50;
	int nb_people <- 0 update: length(people at_distance 1);
	float speed_coeff <- 1.0 update: exp(-nb_people/capacity) min: 0.1;
	bool on_fire <- false;
	
	aspect default {
		rgb road_color <- #black;
		int road_width <- 1;
		
		// Check if this is a permanently safe road
		bool is_permanently_safe <- name in permanently_safe_roads;
		
		// Highlight evacuation center with safety zone
		if (name = evacuation_road_name) {
			road_color <- #green;
			road_width <- 3;
			// Add evacuation safety zone visualization
			draw circle(evacuation_safety_distance) color: rgb(0, 255, 0, 0.1) at: location;
			draw circle(evacuation_safety_distance) color: rgb(0, 200, 0, 0.3) width: 2 at: location empty: true;
			// Add evacuation center marker
			draw circle(40) color: rgb(0, 255, 0, 0.3) at: location;
			draw circle(25) color: rgb(0, 200, 0, 0.5) at: location;
		}
		// Permanently safe roads have a distinct color
		else if (is_permanently_safe) {
			road_color <- rgb(0, 100, 200); // Blue color for safe roads
			road_width <- 2;
		}
		
		// Roads on fire are permanently red and blocked (but this won't happen to safe roads)
		if (on_fire) {
			road_color <- #red;
			road_width <- 4;
		}
		
		draw shape color: road_color width: road_width;
	}
}

species shelter {
	aspect default {
		rgb building_color <- #gray;
		// Draw building
		draw shape color: building_color border: #black width: 1;
	}
}



experiment main type: gui {
	float minimum_cycle_duration <- 0.02;
	output {
		display map type: 3d {
			species road refresh: true;
			species shelter refresh: false;
			species people;
		}
		
		display "Legend" type: 2d {
			graphics "Person Types" {
				// Title
				draw "PERSON TYPES" at: {50, 20} color: #black font: font("Arial", 16, #bold);
				
				// Children
				draw triangle(15) at: {20, 50} color: #blue;
				draw "Children (Slow)" at: {50, 50} color: #black font: font("Arial", 12, #plain);
				draw "Speed: " + string(children_speed) + " km/h" at: {50, 65} color: #gray font: font("Arial", 10, #plain);
				
				// Youth  
				draw triangle(20) at: {20, 90} color: #cyan;
				draw "Youth (Fast)" at: {50, 90} color: #black font: font("Arial", 12, #plain);
				draw "Speed: " + string(youth_speed) + " km/h" at: {50, 105} color: #gray font: font("Arial", 10, #plain);
				
				// Adults
				draw triangle(25) at: {20, 130} color: #orange;
				draw "Adults (Normal)" at: {50, 130} color: #black font: font("Arial", 12, #plain);
				draw "Speed: " + string(adults_speed) + " km/h" at: {50, 145} color: #gray font: font("Arial", 10, #plain);
				
				// Seniors
				draw circle(12) at: {20, 170} color: #purple;
				draw "Seniors (Slow)" at: {50, 170} color: #black font: font("Arial", 12, #plain);
				draw "Speed: " + string(seniors_speed) + " km/h" at: {50, 185} color: #gray font: font("Arial", 10, #plain);
				
				// PWD
				draw square(15) at: {20, 210} color: #magenta;
				draw "PWD (Very Slow)" at: {50, 210} color: #black font: font("Arial", 12, #plain);
				draw "Speed: " + string(pwd_speed) + " km/h" at: {50, 225} color: #gray font: font("Arial", 10, #plain);
				
				// Status Legend
				draw "STATUS COLORS" at: {50, 270} color: #black font: font("Arial", 16, #bold);
				
				// Normal status
				draw triangle(15) at: {20, 300} color: #blue;
				draw "Normal (Not evacuating)" at: {50, 300} color: #black font: font("Arial", 12, #plain);
				
				// Evacuating status
				draw triangle(15) at: {20, 330} color: rgb(255, 165, 0);
				draw "Evacuating (Moving to safety)" at: {50, 330} color: #black font: font("Arial", 12, #plain);
				
				// Fire detected status
				draw triangle(15) at: {20, 360} color: rgb(255, 0, 0);
				draw "Fire Detected (Panic mode)" at: {50, 360} color: #black font: font("Arial", 12, #plain);
				
				// Evacuated status
				draw triangle(15) at: {20, 390} color: #green;
				draw "Evacuated (Safe)" at: {50, 390} color: #black font: font("Arial", 12, #plain);
				
				// Road Legend
				draw "ROAD TYPES" at: {50, 440} color: #black font: font("Arial", 16, #bold);
				
				// Normal roads
				draw line([{20, 470}, {40, 470}]) color: #black width: 2;
				draw "Normal Roads" at: {50, 470} color: #black font: font("Arial", 12, #plain);
				
				// Permanently safe roads
				draw line([{20, 495}, {40, 495}]) color: rgb(0, 100, 200) width: 3;
				draw "Permanently Safe Roads" at: {50, 495} color: #black font: font("Arial", 12, #plain);
				
				// Evacuation center
				draw line([{20, 520}, {40, 520}]) color: #green width: 4;
				draw circle(10) at: {30, 520} color: rgb(0, 255, 0, 0.3);
				draw "Evacuation Center (" + evacuation_road_name + ")" at: {50, 520} color: #black font: font("Arial", 12, #plain);
				
				// Safety zone
				draw circle(15) at: {20, 545} color: rgb(0, 255, 0, 0.2) width: 2 empty: true;
				draw "Safety Zone (Fire-Free)" at: {50, 545} color: #black font: font("Arial", 12, #plain);
				draw "Distance: " + string(int(evacuation_safety_distance)) + "m" at: {50, 560} color: #gray font: font("Arial", 10, #plain);
				
				// Roads on fire
				draw line([{20, 585}, {40, 585}]) color: #red width: 4;
				draw "Roads on Fire (Blocked)" at: {50, 585} color: #black font: font("Arial", 12, #plain);
			}
		}
		
		// Overall evacuation status monitors
		monitor "Normal People" value: length(people where (each.status = "normal"));
		monitor "Evacuating People" value: length(people where (each.status = "evacuating"));
		monitor "Evacuated People" value: length(people where (each.status = "evacuated"));
		monitor "People Detected Fire" value: length(people where each.fire_detected);
		monitor "Total People" value: length(people);
		
		// Person type distribution monitors  
		monitor "Children (Blue ▲)" value: length(people where (each.person_type = "children"));
		monitor "Youth (Cyan ▲)" value: length(people where (each.person_type = "youth"));
		monitor "Adults (Orange ▲)" value: length(people where (each.person_type = "adults"));
		monitor "Seniors (Purple ●)" value: length(people where (each.person_type = "seniors"));
		monitor "PWD (Magenta ■)" value: length(people where (each.person_type = "pwd"));
		
		// Detailed evacuation status by type
		monitor "Children Evacuated" value: length(people where (each.person_type = "children" and each.status = "evacuated"));
		monitor "Youth Evacuated" value: length(people where (each.person_type = "youth" and each.status = "evacuated"));
		monitor "Adults Evacuated" value: length(people where (each.person_type = "adults" and each.status = "evacuated"));
		monitor "Seniors Evacuated" value: length(people where (each.person_type = "seniors" and each.status = "evacuated"));
		monitor "PWD Evacuated" value: length(people where (each.person_type = "pwd" and each.status = "evacuated"));
		
		// Fire status monitors
		monitor "Roads on Fire (Red)" value: length(road where each.on_fire);
		monitor "Safe Roads Available" value: length(road where (not each.on_fire));
		monitor "Permanently Safe Roads" value: length(road where (each.name in permanently_safe_roads));
		monitor "Evacuation Center Safe" value: not (road first_with (each.name = evacuation_road_name)).on_fire;
		
		// Evacuation efficiency monitors
		monitor "Evacuation Rate %" value: length(people where (each.status = "evacuated")) / length(people) * 100.0;
		monitor "Children Evacuation Rate %" value: (length(people where (each.person_type = "children")) > 0) ? 
			(length(people where (each.person_type = "children" and each.status = "evacuated")) / length(people where (each.person_type = "children")) * 100.0) : 0.0;
		monitor "Seniors Evacuation Rate %" value: (length(people where (each.person_type = "seniors")) > 0) ? 
			(length(people where (each.person_type = "seniors" and each.status = "evacuated")) / length(people where (each.person_type = "seniors")) * 100.0) : 0.0;
		monitor "PWD Evacuation Rate %" value: (length(people where (each.person_type = "pwd")) > 0) ? 
			(length(people where (each.person_type = "pwd" and each.status = "evacuated")) / length(people where (each.person_type = "pwd")) * 100.0) : 0.0;
		
		// CHARTS AND GRAPHS
//		display "Evacuation Progress Chart" type: 2d {
//			chart "Evacuation Status Over Time" type: series size: {1.0, 0.5} position: {0, 0} {
//				data "Normal" value: length(people where (each.status = "normal")) color: #blue;
//				data "Evacuating" value: length(people where (each.status = "evacuating")) color: #orange;
//				data "Evacuated" value: length(people where (each.status = "evacuated")) color: #green;
//				data "Fire Detected" value: length(people where each.fire_detected) color: #red;
//			}
//			
//			chart "Fire Spread Over Time" type: series size: {1.0, 0.5} position: {0, 0.5} {
//				data "Roads on Fire" value: length(road where each.on_fire) color: #red marker_shape: marker_square;
//				data "Safe Roads" value: length(road where (not each.on_fire)) color: #green marker_shape: marker_circle;
//			}
//		}
		
//		display "Person Type Analysis" type: 2d {
//			chart "Evacuation Rate by Person Type" type: histogram size: {0.5, 0.5} position: {0, 0} {
//				data "Children" value: (length(people where (each.person_type = "children")) > 0) ? 
//					(length(people where (each.person_type = "children" and each.status = "evacuated")) / length(people where (each.person_type = "children")) * 100.0) : 0.0 color: #blue;
//				data "Youth" value: (length(people where (each.person_type = "youth")) > 0) ? 
//					(length(people where (each.person_type = "youth" and each.status = "evacuated")) / length(people where (each.person_type = "youth")) * 100.0) : 0.0 color: #cyan;
//				data "Adults" value: (length(people where (each.person_type = "adults")) > 0) ? 
//					(length(people where (each.person_type = "adults" and each.status = "evacuated")) / length(people where (each.person_type = "adults")) * 100.0) : 0.0 color: #orange;
//				data "Seniors" value: (length(people where (each.person_type = "seniors")) > 0) ? 
//					(length(people where (each.person_type = "seniors" and each.status = "evacuated")) / length(people where (each.person_type = "seniors")) * 100.0) : 0.0 color: #purple;
//				data "PWD" value: (length(people where (each.person_type = "pwd")) > 0) ? 
//					(length(people where (each.person_type = "pwd" and each.status = "evacuated")) / length(people where (each.person_type = "pwd")) * 100.0) : 0.0 color: #magenta;
//			}
//			
//			chart "Population Distribution" type: pie size: {0.5, 0.5} position: {0.5, 0} {
//				data "Children" value: length(people where (each.person_type = "children")) color: #blue;
//				data "Youth" value: length(people where (each.person_type = "youth")) color: #cyan;
//				data "Adults" value: length(people where (each.person_type = "adults")) color: #orange;
//				data "Seniors" value: length(people where (each.person_type = "seniors")) color: #purple;
//				data "PWD" value: length(people where (each.person_type = "pwd")) color: #magenta;
//			}
//			
//			chart "Evacuation Progress by Type" type: series size: {1.0, 0.5} position: {0, 0.5} {
//				data "Children Evacuated" value: length(people where (each.person_type = "children" and each.status = "evacuated")) color: #blue;
//				data "Youth Evacuated" value: length(people where (each.person_type = "youth" and each.status = "evacuated")) color: #cyan;
//				data "Adults Evacuated" value: length(people where (each.person_type = "adults" and each.status = "evacuated")) color: #orange;
//				data "Seniors Evacuated" value: length(people where (each.person_type = "seniors" and each.status = "evacuated")) color: #purple;
//				data "PWD Evacuated" value: length(people where (each.person_type = "pwd" and each.status = "evacuated")) color: #magenta;
//			}
//		}
		
//		display "Overall Statistics" type: 2d {
//			chart "Total Evacuation Rate" type: series size: {1.0, 0.3} position: {0, 0} 
//				y_range: [0, 100] {
//				data "Evacuation Rate %" value: length(people where (each.status = "evacuated")) / length(people) * 100.0 
//					color: #green style: line thickness: 3;
//			}
//			
//			chart "Average Speed by Status" type: histogram size: {1.0, 0.3} position: {0, 0.35} {
//				data "Normal" value: mean(people where (each.status = "normal") collect each.speed) color: #blue;
//				data "Evacuating" value: mean(people where (each.status = "evacuating") collect each.speed) color: #orange;
//				data "Fire Detected" value: mean(people where (each.fire_detected) collect each.speed) color: #red;
//			}
//			
//			chart "Fire vs Safe Infrastructure" type: radar size: {1.0, 0.35} position: {0, 0.65} {
//				data "Roads on Fire %" value: (length(road where each.on_fire) / length(road) * 100.0) color: #red;
//				data "Safe Roads %" value: (length(road where (not each.on_fire)) / length(road) * 100.0) color: #green;
//				data "Permanently Safe %" value: (length(road where (each.name in permanently_safe_roads)) / length(road) * 100.0) color: #blue;
//			}
//		}
	}
}