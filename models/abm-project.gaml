/**
* Name: Simple Random Walk with Evacuation - Multi-Type People
* Description: People of different types (children, youth, adults, seniors, PWD) walk to road136 and get evacuated with visual status
* Features: Certain roads are permanently safe from fire and will never burn. Shelters catch fire when near burning roads.
* shelter176 is marked as the evacuation site.
*/

model Simple_Random_Walk_Evacuation

global {
	file shapefile_roads <- file("../includes/pathway.shp");
	file shapefile_shelters <- file("../includes/lahug-final.shp");

	geometry shape <- envelope(shapefile_roads);
	graph road_network;
	graph safe_road_network; // Network excluding roads on fire
	map<road,float> current_weights;
	
	// Fire parameters
	float fire_spread_probability <- 0.1; // Balanced spread rate
	float fire_detection_distance <- 150.0;
	float fire_spread_distance <- 250.0; // Reasonable spread distance
	float shelter_fire_distance <- 150.0; // Distance for shelters to catch fire from roads
	int initial_fire_roads <- 1; // Start with 1 fire source
	string evacuation_road_name <- "road136";
	string fire_start_road_name <- "road28"; // Fire always starts here
	float evacuation_safety_distance <- 300.0 parameter: "Evacuation Safety Distance (m)" category: "Fire Parameters" min: 100.0 max: 1000.0;
	
	// Gradual fire system parameters
	float fire_intensity_increase <- 0.15 parameter: "Fire Intensity Increase Rate" category: "Fire Parameters" min: 0.05 max: 0.5;
	float fire_spread_threshold <- 0.3 parameter: "Fire Spread Threshold" category: "Fire Parameters" min: 0.1 max: 0.9;
	float fire_full_intensity <- 1.0; // Maximum fire intensity
	float fire_ignition_intensity <- 0.1; // Initial fire intensity when ignited
	
	// Mortality parameters
	float death_fire_threshold <- 0.7 parameter: "Fire Intensity for Death Risk" category: "Mortality Parameters" min: 0.3 max: 1.0;
	float death_probability_base <- 0.02 parameter: "Base Death Probability per Cycle" category: "Mortality Parameters" min: 0.001 max: 0.1;
	float death_distance_threshold <- 50.0 parameter: "Death Distance from High Fire (m)" category: "Mortality Parameters" min: 10.0 max: 200.0;
	
	// Age-based mortality multipliers
	float children_death_multiplier <- 1.5 parameter: "Children Death Risk Multiplier" category: "Mortality Parameters" min: 0.5 max: 3.0;
	float youth_death_multiplier <- 0.8 parameter: "Youth Death Risk Multiplier" category: "Mortality Parameters" min: 0.3 max: 2.0;
	float adults_death_multiplier <- 1.0 parameter: "Adults Death Risk Multiplier" category: "Mortality Parameters" min: 0.5 max: 2.0;
	float seniors_death_multiplier <- 2.0 parameter: "Seniors Death Risk Multiplier" category: "Mortality Parameters" min: 1.0 max: 4.0;
	float pwd_death_multiplier <- 2.5 parameter: "PWD Death Risk Multiplier" category: "Mortality Parameters" min: 1.0 max: 5.0;
	
	// List of permanently safe roads that will never catch fire
	list<string> permanently_safe_roads <- [
		"road131", "road120", "road130", "road142", "road119", "road123", 
		"road146", "road108", "road150", "road134", "road115", "road151", 
		"road133", "road137", "road136", "road138", "road148", "road149", 
		"road152", "road118", "road143", "road147", "road129", "road122", 
		"road140", "road139", "road141", "road144", "road135", "road145"
	];
	
	// People type parameters - speeds in km/h (based on research data)
	// Research data: Children 1.45m/s, Youth 1.61m/s, Adults 1.64m/s, Seniors 1.32m/s, PWD 1.1m/s
	// Multiplied by 5 for faster simulation
	float children_speed <- 26.1 parameter: "Children Speed (km/h)" category: "People Speeds";
	float youth_speed <- 28.98 parameter: "Youth Speed (km/h)" category: "People Speeds";
	float adults_speed <- 29.52 parameter: "Adults Speed (km/h)" category: "People Speeds";
	float seniors_speed <- 23.76 parameter: "Seniors Speed (km/h)" category: "People Speeds";
	float pwd_speed <- 19.8 parameter: "PWD Speed (km/h)" category: "People Speeds";
	
	// People type proportions
	float children_ratio <- 0.45 parameter: "Children Ratio" category: "People Distribution" min: 0.0 max: 1.0;
	float youth_ratio <- 0.15 parameter: "Youth Ratio" category: "People Distribution" min: 0.0 max: 1.0;
	float adults_ratio <- 0.30 parameter: "Adults Ratio" category: "People Distribution" min: 0.0 max: 1.0;
	float seniors_ratio <- 0.05 parameter: "Seniors Ratio" category: "People Distribution" min: 0.0 max: 1.0;
	float pwd_ratio <- 0.05 parameter: "PWD Ratio" category: "People Distribution" min: 0.0 max: 1.0;
	
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
				fire_intensity <- fire_ignition_intensity; // Start with low intensity
				write "🔥 Fire started at " + fire_start_road_name + " (initial intensity: " + fire_intensity + ")";
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
					fire_intensity <- fire_ignition_intensity; // Start with low intensity
					write "🔥 Fire started at random road: " + name + " (initial intensity: " + fire_intensity + ")";
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
		
		// Gradual fire spreading - roads with high intensity can ignite nearby roads
		list<road> fire_roads <- road where (each.fire_intensity >= fire_spread_threshold);
		list<road> safe_roads <- road where (each.fire_intensity = 0.0 and each.name != evacuation_road_name and not (each.name in permanently_safe_roads));
		
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
							// Spread chance depends on source fire intensity and distance
							float spread_chance <- fire_spread_probability * myself.fire_intensity * (1.0 - distance_to_fire / fire_spread_distance);
							
							if (flip(spread_chance)) {
								fire_intensity <- fire_ignition_intensity; // Start new fire with low intensity
								write "🔥 Fire spread to new road: " + name + " (distance: " + int(distance_to_fire) + "m, intensity: " + fire_intensity + ")";
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
	
	// Check and spread fire to nearby shelters
	reflex shelter_fire_spread when: every(5#cycle) {
		// Get all roads that have significant fire intensity
		list<road> fire_roads <- road where (each.fire_intensity >= fire_spread_threshold);
		
		if (not empty(fire_roads)) {
			// Check each shelter that is not yet on fire
			ask shelter where (not each.on_fire) {
				// Check if any fire road is within the shelter fire distance
				list<road> nearby_fire_roads <- fire_roads where (each.location distance_to self.location <= shelter_fire_distance);
				
				if (not empty(nearby_fire_roads)) {
					// Set shelter on fire based on nearby fire intensity
					float max_nearby_intensity <- max(nearby_fire_roads collect each.fire_intensity);
					float ignition_chance <- max_nearby_intensity * 0.3; // 30% chance at full intensity
					
					if (flip(ignition_chance)) {
						on_fire <- true;
						write "🏠🔥 Shelter caught fire! (distance to nearest fire road: " + 
							int(min(nearby_fire_roads collect (each.location distance_to self.location))) + "m, max fire intensity: " + max_nearby_intensity + ")";
					}
				}
			}
		}
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
	string status <- "normal"; // normal, evacuating, evacuated, dead
	bool fire_detected <- false;
	float fire_exposure_time <- 0.0; // Time spent near high-intensity fire
	int evacuation_start_time <- -1; // Cycle when evacuation started
	int evacuation_end_time <- -1; // Cycle when evacuation completed
	float total_evacuation_time <- 0.0; // Total time taken to evacuate (in cycles)
	
	init {
		// Find evacuation road and set it as target road
		target_road <- road first_with (each.name = evacuation_road_name);
		if (target_road = nil) {
			// If evacuation road not found, use first road as fallback
			target_road <- first(road);
		}
	}
	
	// Check for death conditions
	reflex check_mortality when: status != "evacuated" and status != "dead" {
		// Find nearby high-intensity fire roads
		list<road> deadly_fire_roads <- road where (each.fire_intensity >= death_fire_threshold and 
			each.location distance_to location <= death_distance_threshold);
		
		if (not empty(deadly_fire_roads)) {
			// Calculate death probability based on fire intensity and person type
			float max_fire_intensity <- max(deadly_fire_roads collect each.fire_intensity);
			float distance_to_fire <- min(deadly_fire_roads collect (each.location distance_to location));
			
			// Base death probability increases with fire intensity and decreases with distance
			float death_prob <- death_probability_base * max_fire_intensity * 
				(1.0 - distance_to_fire / death_distance_threshold);
			
			// Apply person-type multiplier
			switch person_type {
				match "children" { death_prob <- death_prob * children_death_multiplier; }
				match "youth" { death_prob <- death_prob * youth_death_multiplier; }
				match "adults" { death_prob <- death_prob * adults_death_multiplier; }
				match "seniors" { death_prob <- death_prob * seniors_death_multiplier; }
				match "pwd" { death_prob <- death_prob * pwd_death_multiplier; }
			}
			
			// Increase exposure time
			fire_exposure_time <- fire_exposure_time + 1.0;
			
			// Death probability increases with prolonged exposure
			death_prob <- death_prob * (1.0 + fire_exposure_time * 0.1);
			
			// Check for death
			if (flip(death_prob)) {
				status <- "dead";
				color <- #black;
				speed <- 0.0;
				target <- nil;
				write "💀 " + person_type + " died from fire exposure! (Fire intensity: " + 
					max_fire_intensity + ", Distance: " + int(distance_to_fire) + "m, Exposure time: " + 
					int(fire_exposure_time) + " cycles)";
			}
		} else {
			// Reset exposure time if not near deadly fire
			fire_exposure_time <- 0.0;
		}
	}
	
	reflex detect_fire when: status != "evacuated" and status != "dead" {
		// Check if there's fire nearby (from roads or shelters) - detect fire earlier with intensity system
		list<road> nearby_fire_roads <- road where (each.fire_intensity > 0.1 and each.location distance_to location < fire_detection_distance);
		list<shelter> nearby_fire_shelters <- shelter where (each.on_fire and each.location distance_to location < fire_detection_distance);
		
		if ((not empty(nearby_fire_roads) or not empty(nearby_fire_shelters)) and not fire_detected) {
			fire_detected <- true;
			// Get maximum fire intensity nearby for panic level
			float max_fire_intensity <- 0.0;
			if (not empty(nearby_fire_roads)) {
				max_fire_intensity <- max(nearby_fire_roads collect each.fire_intensity);
			}
			
			// Start evacuating immediately if fire is detected
			if (status = "normal") {
				status <- "evacuating";
				evacuation_start_time <- cycle; // Record when evacuation started
				// Change color to red but keep type distinction with brightness - intensity affects color
				float panic_level <- max_fire_intensity; // Use fire intensity to determine panic level
				switch person_type {
					match "children" { color <- rgb(int(255 * panic_level + 100), int(100 * panic_level), int(100 * panic_level)); } // Light red
					match "youth" { color <- rgb(255, 0, int(100 * panic_level)); } // Red-magenta
					match "adults" { color <- rgb(255, 0, 0); } // Pure red
					match "seniors" { color <- rgb(int(200 * panic_level + 55), 0, 0); } // Dark red
					match "pwd" { color <- rgb(int(150 * panic_level + 105), 0, 0); } // Very dark red
				}
				// Increase evacuation speed (but maintain type-based differences)
				float panic_multiplier <- 1.1 + (0.4 * panic_level); // 10-50% speed increase based on fire intensity
				switch person_type {
					match "children" { panic_multiplier <- 1.1 + (0.2 * panic_level); } // Children don't panic as much
					match "youth" { panic_multiplier <- 1.2 + (0.6 * panic_level); } // Youth can move much faster when panicking
					match "adults" { panic_multiplier <- 1.1 + (0.4 * panic_level); }
					match "seniors" { panic_multiplier <- 1.05 + (0.15 * panic_level); } // Limited panic boost for seniors
					match "pwd" { panic_multiplier <- 1.02 + (0.08 * panic_level); } // Very limited boost for PWD
				}
				speed <- base_speed * panic_multiplier #km/#h;
				target <- nil; // Reset target to force new pathfinding
			}
		}
	}
	
	reflex walk_to_target_road when: status != "evacuated" and status != "dead" {
		// If no target, pick a location on the target road
		if (target = nil) {
			target <- any_location_in(target_road);
			if (status = "normal") {
				status <- "evacuating";
				evacuation_start_time <- cycle; // Record when evacuation started
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
				evacuation_end_time <- cycle; // Record when evacuation completed
				if (evacuation_start_time >= 0) {
					total_evacuation_time <- (evacuation_end_time - evacuation_start_time) / 5.0; // Divide by 5 to compensate for 5x speed
				}
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
		// Dead people have a special appearance
		if (status = "dead") {
			draw "💀" at: location color: #black font: font("Arial", 20, #bold);
			draw circle(25) color: rgb(0, 0, 0, 0.3) at: location; // Dark circle around dead person
		} else {
			// Different shapes for different person types (living people)
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
}

species road {
	float capacity <- 1 + shape.perimeter/50;
	int nb_people <- 0 update: length(people at_distance 1);
	float speed_coeff <- 1.0 update: exp(-nb_people/capacity) min: 0.1;
	float fire_intensity <- 0.0; // Gradual fire intensity from 0.0 (no fire) to 1.0 (full fire)
	bool on_fire <- false update: fire_intensity >= fire_spread_threshold; // For compatibility with existing code
	
	// Gradual fire buildup
	reflex fire_buildup when: fire_intensity > 0.0 and fire_intensity < fire_full_intensity and not (name in permanently_safe_roads) {
		fire_intensity <- fire_intensity + fire_intensity_increase;
		if (fire_intensity > fire_full_intensity) {
			fire_intensity <- fire_full_intensity;
		}
	}
	
	aspect default {
		rgb road_color <- #black;
		int road_width <- 1;
		
		// Check if this is a permanently safe road
		bool is_permanently_safe <- name in permanently_safe_roads;
		
		// Highlight evacuation center with safety zone
		if (name = evacuation_road_name) {
			road_color <- #green;
			road_width <- 3;
			// Add evacuation center marker
			draw circle(40) color: rgb(0, 255, 0, 0.3) at: location;
			draw circle(25) color: rgb(0, 200, 0, 0.5) at: location;
		}
		// Permanently safe roads have a distinct color
		else if (is_permanently_safe) {
			road_color <- rgb(0, 100, 200); // Blue color for safe roads
			road_width <- 2;
		}
		
		// Gradual fire visualization - roads change color based on fire intensity
		if (fire_intensity > 0.0) {
			// Gradual color transition from black -> orange -> red
			if (fire_intensity < 0.3) {
				// Early fire: dark orange
				int intensity_255 <- int(255 * (fire_intensity / 0.3));
				road_color <- rgb(intensity_255, int(intensity_255 * 0.3), 0);
				road_width <- 2;
			} else if (fire_intensity < 0.7) {
				// Medium fire: bright orange
				int intensity_255 <- int(255 * ((fire_intensity - 0.3) / 0.4));
				road_color <- rgb(255, int(165 - intensity_255 * 0.6), 0);
				road_width <- 3;
			} else {
				// High fire: red
				int intensity_255 <- int(255 * ((fire_intensity - 0.7) / 0.3));
				road_color <- rgb(255, int(50 - intensity_255 * 0.2), 0);
				road_width <- 4;
			}
			
			// Add fire effects for high intensity
			if (fire_intensity > 0.5) {
				draw circle(20 + fire_intensity * 30) color: rgb(255, 100, 0, int(100 * fire_intensity)) at: location;
			}
		}
		
		draw shape color: road_color width: road_width;
	}
}

species shelter {
	bool on_fire <- false;
	aspect default {
		rgb building_color <- #gray;
		
		// Check if this is the evacuation shelter
		if (name = "shelter176") {
			building_color <- #green;
		}
		
		// Check if shelter is on fire and override color
		if (on_fire) {
			building_color <- #red;
		}
		
		// Draw building with the correct color
		draw shape color: building_color border: #black width: 1;
		
		// Add fire emoji for burning shelters
		if (on_fire) {
			draw "🔥" at: location color: #orange font: font("Arial", 16, #bold);
		}
		
		// Add label for evacuation shelter
		if (name = "shelter176") {
			draw "EVACUATION SITE" at: location + {0, -30} color: #darkgreen font: font("Arial", 14, #bold);
		}
	}
}

experiment main type: gui {
	float minimum_cycle_duration <- 0.0; // Maximum speed - no delay between cycles
	output {
		display map type: 3d {
			species road refresh: true;
			species shelter refresh: true;
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
				
				// Dead status
				draw "💀" at: {20, 420} color: #black font: font("Arial", 15, #bold);
				draw "Dead (Fire victim)" at: {50, 420} color: #black font: font("Arial", 12, #plain);
				
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
				
				// Roads on fire
				draw line([{20, 545}, {40, 545}]) color: #red width: 4;
				draw "Roads on Fire (Blocked)" at: {50, 545} color: #black font: font("Arial", 12, #plain);
				
				// Fire intensity legend
				draw "FIRE INTENSITY LEVELS" at: {50, 575} color: #black font: font("Arial", 14, #bold);
				
				// Low fire intensity
				draw line([{20, 600}, {40, 600}]) color: rgb(100, 30, 0) width: 2;
				draw "Low Fire (0.1-0.3)" at: {50, 600} color: #black font: font("Arial", 10, #plain);
				
				// Medium fire intensity  
				draw line([{20, 620}, {40, 620}]) color: rgb(255, 100, 0) width: 3;
				draw "Medium Fire (0.3-0.7)" at: {50, 620} color: #black font: font("Arial", 10, #plain);
				
				// High fire intensity
				draw line([{20, 640}, {40, 640}]) color: rgb(255, 30, 0) width: 4;
				draw "High Fire (0.7-1.0)" at: {50, 640} color: #black font: font("Arial", 10, #plain);
				
				// Building Legend
				draw "BUILDING TYPES" at: {50, 695} color: #black font: font("Arial", 16, #bold);
				
				// Normal shelter
				draw square(20) at: {20, 725} color: #gray;
				draw "Normal Shelter" at: {50, 725} color: #black font: font("Arial", 12, #plain);
				
				// Evacuation shelter
				draw square(20) at: {20, 755} color: #green;
				draw "Evacuation Site (shelter176)" at: {50, 755} color: #black font: font("Arial", 12, #plain);
				
				// Shelter on fire
				draw square(20) at: {20, 785} color: #red;
				draw "🔥" at: {20, 785} font: font("Arial", 12, #bold) color: #orange;
				draw "Shelter on Fire" at: {50, 785} color: #black font: font("Arial", 12, #plain);
				draw "Fire radius: " + string(int(shelter_fire_distance)) + "m" at: {50, 800} color: #gray font: font("Arial", 10, #plain);
			}
		}
		
		// Demographic Counts and Evacuation Times
		monitor "Children Count" value: length(people where (each.person_type = "children"));
		monitor "Children Simulation Time (s)" value: (length(people where (each.person_type = "children" and each.status = "evacuated" and each.total_evacuation_time > 0)) > 0) ? 
			mean(people where (each.person_type = "children" and each.status = "evacuated" and each.total_evacuation_time > 0) collect each.total_evacuation_time) : 0.0;
		monitor "Children Real-Life Time (s)" value: (length(people where (each.person_type = "children" and each.status = "evacuated" and each.total_evacuation_time > 0)) > 0) ? 
			mean(people where (each.person_type = "children" and each.status = "evacuated" and each.total_evacuation_time > 0) collect (each.total_evacuation_time * 5.0)) : 0.0;
			
		monitor "Youth Count" value: length(people where (each.person_type = "youth"));
		monitor "Youth Simulation Time (s)" value: (length(people where (each.person_type = "youth" and each.status = "evacuated" and each.total_evacuation_time > 0)) > 0) ? 
			mean(people where (each.person_type = "youth" and each.status = "evacuated" and each.total_evacuation_time > 0) collect each.total_evacuation_time) : 0.0;
		monitor "Youth Real-Life Time (s)" value: (length(people where (each.person_type = "youth" and each.status = "evacuated" and each.total_evacuation_time > 0)) > 0) ? 
			mean(people where (each.person_type = "youth" and each.status = "evacuated" and each.total_evacuation_time > 0) collect (each.total_evacuation_time * 5.0)) : 0.0;
			
		monitor "Adults Count" value: length(people where (each.person_type = "adults"));
		monitor "Adults Simulation Time (s)" value: (length(people where (each.person_type = "adults" and each.status = "evacuated" and each.total_evacuation_time > 0)) > 0) ? 
			mean(people where (each.person_type = "adults" and each.status = "evacuated" and each.total_evacuation_time > 0) collect each.total_evacuation_time) : 0.0;
		monitor "Adults Real-Life Time (s)" value: (length(people where (each.person_type = "adults" and each.status = "evacuated" and each.total_evacuation_time > 0)) > 0) ? 
			mean(people where (each.person_type = "adults" and each.status = "evacuated" and each.total_evacuation_time > 0) collect (each.total_evacuation_time * 5.0)) : 0.0;
			
		monitor "Seniors Count" value: length(people where (each.person_type = "seniors"));
		monitor "Seniors Simulation Time (s)" value: (length(people where (each.person_type = "seniors" and each.status = "evacuated" and each.total_evacuation_time > 0)) > 0) ? 
			mean(people where (each.person_type = "seniors" and each.status = "evacuated" and each.total_evacuation_time > 0) collect each.total_evacuation_time) : 0.0;
		monitor "Seniors Real-Life Time (s)" value: (length(people where (each.person_type = "seniors" and each.status = "evacuated" and each.total_evacuation_time > 0)) > 0) ? 
			mean(people where (each.person_type = "seniors" and each.status = "evacuated" and each.total_evacuation_time > 0) collect (each.total_evacuation_time * 5.0)) : 0.0;
			
		monitor "PWD Count" value: length(people where (each.person_type = "pwd"));
		monitor "PWD Simulation Time (s)" value: (length(people where (each.person_type = "pwd" and each.status = "evacuated" and each.total_evacuation_time > 0)) > 0) ? 
			mean(people where (each.person_type = "pwd" and each.status = "evacuated" and each.total_evacuation_time > 0) collect each.total_evacuation_time) : 0.0;
		monitor "PWD Real-Life Time (s)" value: (length(people where (each.person_type = "pwd" and each.status = "evacuated" and each.total_evacuation_time > 0)) > 0) ? 
			mean(people where (each.person_type = "pwd" and each.status = "evacuated" and each.total_evacuation_time > 0) collect (each.total_evacuation_time * 5.0)) : 0.0;
			
		monitor "Overall Simulation Time (s)" value: (length(people where (each.status = "evacuated" and each.total_evacuation_time > 0)) > 0) ? 
			mean(people where (each.status = "evacuated" and each.total_evacuation_time > 0) collect each.total_evacuation_time) : 0.0;
		monitor "Overall Real-Life Time (s)" value: (length(people where (each.status = "evacuated" and each.total_evacuation_time > 0)) > 0) ? 
			mean(people where (each.status = "evacuated" and each.total_evacuation_time > 0) collect (each.total_evacuation_time * 5.0)) : 0.0;
		
		// CHARTS AND GRAPHS
		display "Evacuation Progress Chart" type: 2d {
			chart "Evacuation Status Over Time" type: series size: {1.0, 0.5} position: {0, 0} {
				data "Normal" value: length(people where (each.status = "normal")) color: #blue;
				data "Evacuating" value: length(people where (each.status = "evacuating")) color: #orange;
				data "Evacuated" value: length(people where (each.status = "evacuated")) color: #green;
				data "Fire Detected" value: length(people where each.fire_detected) color: #red;
			}
			
			chart "Fire Spread Over Time" type: series size: {1.0, 0.5} position: {0, 0.5} {
				data "Roads on Fire" value: length(road where each.on_fire) color: #red marker_shape: marker_square;
				data "Safe Roads" value: length(road where (not each.on_fire)) color: #green marker_shape: marker_circle;
			}
		}
		
		display "Person Type Analysis" type: 2d {
			chart "Evacuation Rate by Person Type" type: histogram size: {0.5, 0.5} position: {0, 0} {
				data "Children" value: (length(people where (each.person_type = "children")) > 0) ? 
					(length(people where (each.person_type = "children" and each.status = "evacuated")) / length(people where (each.person_type = "children")) * 100.0) : 0.0 color: #blue;
				data "Youth" value: (length(people where (each.person_type = "youth")) > 0) ? 
					(length(people where (each.person_type = "youth" and each.status = "evacuated")) / length(people where (each.person_type = "youth")) * 100.0) : 0.0 color: #cyan;
				data "Adults" value: (length(people where (each.person_type = "adults")) > 0) ? 
					(length(people where (each.person_type = "adults" and each.status = "evacuated")) / length(people where (each.person_type = "adults")) * 100.0) : 0.0 color: #orange;
				data "Seniors" value: (length(people where (each.person_type = "seniors")) > 0) ? 
					(length(people where (each.person_type = "seniors" and each.status = "evacuated")) / length(people where (each.person_type = "seniors")) * 100.0) : 0.0 color: #purple;
				data "PWD" value: (length(people where (each.person_type = "pwd")) > 0) ? 
					(length(people where (each.person_type = "pwd" and each.status = "evacuated")) / length(people where (each.person_type = "pwd")) * 100.0) : 0.0 color: #magenta;
			}
			
			chart "Population Distribution" type: pie size: {0.5, 0.5} position: {0.5, 0} {
				data "Children" value: length(people where (each.person_type = "children")) color: #blue;
				data "Youth" value: length(people where (each.person_type = "youth")) color: #cyan;
				data "Adults" value: length(people where (each.person_type = "adults")) color: #orange;
				data "Seniors" value: length(people where (each.person_type = "seniors")) color: #purple;
				data "PWD" value: length(people where (each.person_type = "pwd")) color: #magenta;
			}
			
			chart "Evacuation Progress by Type" type: series size: {1.0, 0.5} position: {0, 0.5} {
				data "Children Evacuated" value: length(people where (each.person_type = "children" and each.status = "evacuated")) color: #blue;
				data "Youth Evacuated" value: length(people where (each.person_type = "youth" and each.status = "evacuated")) color: #cyan;
				data "Adults Evacuated" value: length(people where (each.person_type = "adults" and each.status = "evacuated")) color: #orange;
				data "Seniors Evacuated" value: length(people where (each.person_type = "seniors" and each.status = "evacuated")) color: #purple;
				data "PWD Evacuated" value: length(people where (each.person_type = "pwd" and each.status = "evacuated")) color: #magenta;
			}
		}
		
		display "Overall Statistics" type: 2d {
			chart "Total Evacuation Rate" type: series size: {1.0, 0.3} position: {0, 0} 
				y_range: [0, 100] {
				data "Evacuation Rate %" value: length(people where (each.status = "evacuated")) / length(people) * 100.0 
					color: #green style: line thickness: 3;
			}
			
			chart "Average Speed by Status" type: histogram size: {1.0, 0.3} position: {0, 0.35} {
				data "Normal" value: mean(people where (each.status = "normal") collect each.speed) color: #blue;
				data "Evacuating" value: mean(people where (each.status = "evacuating") collect each.speed) color: #orange;
				data "Fire Detected" value: mean(people where (each.fire_detected) collect each.speed) color: #red;
			}
			
			chart "Fire vs Safe Infrastructure" type: radar size: {1.0, 0.35} position: {0, 0.65} {
				data "Roads on Fire %" value: (length(road where each.on_fire) / length(road) * 100.0) color: #red;
				data "Safe Roads %" value: (length(road where (not each.on_fire)) / length(road) * 100.0) color: #green;
				data "Permanently Safe %" value: (length(road where (each.name in permanently_safe_roads)) / length(road) * 100.0) color: #blue;
			}
		}
	}
}