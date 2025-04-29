/**
* Name: evacuation
* Based on the internal empty template.
* Author: estud
* Tags: evacuation, GIS, Lahug, fire
*/

model evacuation

global {
    // Load the building shapefile
    file building_shapefile <- file("../includes/lahug.shp") parameter: "Building Shapefile:" category: "GIS specific";
    
    // Load the pathway shapefile
    file pathway_shapefile <- file("../includes/pathway.shp") parameter: "Pathway Shapefile:" category: "GIS specific";
    
    // Define the geographical bounds for the simulation based on both shapefiles
    geometry shape <- envelope(building_shapefile) + envelope(pathway_shapefile);
    
    // Parameter for building heights
    float min_height <- 2.0 parameter: "Minimum building height:" category: "Buildings";
    float max_height <- 5.0 parameter: "Maximum building height:" category: "Buildings";
    
    // Parameter for number of people
    int nb_people_per_building <- 5 parameter: "Number of people per building:" category: "People";
    
    // Parameters for evacuation
    bool evacuation_started <- false parameter: "Start evacuation" category: "Evacuation";
    float person_speed <- 1.0 parameter: "Person speed" category: "People";
    
    // Parameters for fire simulation
    bool fire_started <- false parameter: "Start fire" category: "Fire";
    float fire_spread_probability <- 0.3 parameter: "Fire spread probability" min: 0.0 max: 1.0 category: "Fire";
    int fire_spread_radius <- 15 parameter: "Fire spread radius" min: 5 max: 50 category: "Fire";
    
    // Keep track of the evacuation center
    building evacuation_center;
    
    // For fire starting
    building fire_source;
    
    init {
        // Create building agents from the building shapefile
        create building from: building_shapefile {
            // Assign random heights to buildings, between min and max
            height <- rnd(min_height, max_height);
            
            // Create an exit point for each building
            // The exit is on the border of the shape
            exit_point <- any_location_in(shape.contour);
            
            // Create a visual indicator for the exit
            create exit_indicator number: 1 {
                location <- myself.exit_point;
                my_building <- myself;
            }
        }
        write "Building shapefile loaded successfully with " + length(building) + " buildings.";
        
        // Create pathway agents from the pathway shapefile
        create pathway from: pathway_shapefile;
        write "Pathway shapefile loaded successfully with " + length(pathway) + " pathways.";
        
        // Set building0 as the evacuation center
        evacuation_center <- building at 0;
        ask evacuation_center {
            name <- "building0";
            is_evacuation_center <- true;
        }
        write "Evacuation center established at building0";
        
        // Set a random building (not evacuation center) as initial fire source
        fire_source <- one_of(building - evacuation_center);
        
        // Create person agents inside regular buildings (not in the evacuation center)
        create person number: (length(building) - 1) * nb_people_per_building {
            // Randomly place people in buildings that are not the evacuation center
            building my_building <- one_of(building - evacuation_center);
            location <- any_location_in(my_building.shape);
            my_home <- my_building;
            speed <- person_speed;
        }
        write "Created " + length(person) + " people inside regular buildings.";
    }
    
    // Action to start the fire
    reflex manage_fire when: fire_started and !evacuation_started {
        // Start fire in the designated source building
        ask fire_source {
            is_on_fire <- true;
            fire_intensity <- 1.0;
            
            // Create fire visual effect
            create fire number: 5 {
                location <- any_location_in(myself.shape);
                intensity <- myself.fire_intensity;
                my_building <- myself;
            }
        }
        
        // Automatically start evacuation when fire begins
        evacuation_started <- true;
        write "ALERT: Fire detected in building! Evacuation has started.";
    }
    
    // Fire spreading mechanism
    reflex spread_fire when: fire_started {
        // Get list of buildings currently on fire
        list<building> burning_buildings <- building where (each.is_on_fire);
        
        // For each burning building, check neighbors for spreading
        ask burning_buildings {
            // Increase fire intensity
            fire_intensity <- min(1.0, fire_intensity + 0.05);
            
            // Update fire visuals
            ask fire where (each.my_building = self) {
                intensity <- myself.fire_intensity;
                // Create smoke particles as fire grows
                if (flip(intensity * 0.2)) {
                    create smoke {
                        location <- any_location_in(myself.my_building.shape);
                        speed <- 0.5;
                        heading <- 90.0;
                    }
                }
            }
            
            // Attempt to spread fire to nearby buildings
            list<building> nearby_buildings <- (building at_distance fire_spread_radius) - self;
            ask nearby_buildings {
                // Calculate distance and handle potential zero distance
                float dist <- self distance_to myself;
                // Prevent division by zero by using a minimum distance of 0.1
                dist <- max(0.1, dist);
                
                // Calculate fire spread chance based on distance and intensity
                float spread_chance <- fire_spread_probability * myself.fire_intensity / dist;
                
                // Cap the maximum spread chance at 80%
                spread_chance <- min(0.8, spread_chance);
                
                if (!is_on_fire and !is_evacuation_center and flip(spread_chance)) {
                    is_on_fire <- true;
                    fire_intensity <- 0.3;
                    
                    // Create fire visual in newly burning building
                    create fire number: 3 {
                        location <- any_location_in(myself.shape);
                        intensity <- myself.fire_intensity;
                        my_building <- myself;
                    }
                    
                    write "Fire has spread to another building!";
                }
            }
        }
    }
    
    // Action to start the evacuation process
    reflex manage_evacuation when: evacuation_started {
        ask person {
            is_evacuating <- true;
        }
    }
    
    // Monitor evacuation status (but don't pause)
    reflex monitor_evacuation when: evacuation_started {
        int people_evacuated <- person count (each.my_home = evacuation_center);
        int people_perished <- person count (each.is_dead);
        int total_people <- length(person);
        
        // If everyone has been evacuated or perished, just report it
        if (people_evacuated + people_perished = total_people) {
            write "ALL PEOPLE ACCOUNTED FOR: " + people_evacuated + " people safely evacuated, " + people_perished + " casualties.";
        }
    }
}

// Define a pathway species for the pathways shapefile
species pathway {
    aspect default {
        draw shape color: #blue border: #black;
    }
    
    aspect elevated {
        draw shape color: rgb(0, 0, 255, 150) border: #black depth: 0.1;
    }
}

// Define a smoke particle species for visual effects
species smoke skills: [moving] {
    int lifetime <- rnd(20, 40);
    
    reflex move {
        do wander amplitude: 45.0;
        do move;
        lifetime <- lifetime - 1;
        if (lifetime <= 0) { do die; }
    }
    
    aspect default {
        draw circle(1.0 + rnd(0.5)) color: rgb(100, 100, 100, 150);
    }
}

// Define a fire particle species for visual effects
species fire {
    building my_building;
    float intensity <- 0.5;
    
    aspect default {
        draw circle(1.0 + intensity) color: rgb(255, 50 + rnd(50), rnd(50));
    }
    
    aspect elevated {
        draw sphere(1.0 + intensity) color: rgb(255, 50 + rnd(50), rnd(50));
    }
}

// Define a species for the buildings with height
species building {
    float height;
    bool is_evacuation_center <- false; // Flag for evacuation center
    point exit_point;  // The exit point for this building
    bool is_on_fire <- false; // Whether building is on fire
    float fire_intensity <- 0.0; // Intensity of fire (0.0 to 1.0)
    
    aspect default {
        rgb color <- is_evacuation_center ? #yellow : (is_on_fire ? rgb(255, 0, 0, 150 + int(fire_intensity * 100)) : #gray);
        draw shape color: color border: #black;
    }
    
    // 3D aspect for buildings with elevation and transparency
    aspect elevated {
        // Choose color based on building state
        rgb wall_color <- is_evacuation_center ? 
                        rgb(255, 255, 0, 200) : 
                        (is_on_fire ? rgb(255, 50, 50, 150 + int(fire_intensity * 100)) : rgb(150, 150, 150, 200));
        
        rgb roof_color <- is_evacuation_center ? 
                        rgb(255, 255, 0, 50) : 
                        (is_on_fire ? rgb(255, 50, 50, 100) : rgb(200, 200, 200, 50));
        
        // Draw walls
        draw shape depth: height color: wall_color border: #black;
        // Draw transparent roof to see inside
        draw shape at: {location.x, location.y, height} color: roof_color border: #black;
    }
}

// Define a visual indicator for building exits
species exit_indicator {
    building my_building;
    
    aspect default {
        draw triangle(1.0) color: #red border: #black;
    }
    
    aspect elevated {
        draw pyramid(1.0) color: #red border: #black;
    }
}

// Define the person species
species person skills: [moving] {
    building my_home;
    bool is_evacuating <- false;
    bool has_exited <- false;
    point target <- nil;
    bool is_dead <- false;
    bool is_safe <- false;  // Flag to indicate person is safely in evacuation center
    
    // Check if the person is in danger from fire
    reflex check_fire_danger when: !is_dead and !is_safe {
        // If person's current building is on fire, increase danger
        if (my_home.is_on_fire) {
            // Chance of death increases with fire intensity
            if (flip(my_home.fire_intensity * 0.05)) {
                is_dead <- true;
                is_evacuating <- false;
                write "A person has perished in the fire.";
            }
        }
    }
    
    // Evacuation behavior
    reflex evacuate when: is_evacuating and !is_dead and !is_safe {
        if (!has_exited) {
            // First, head to the exit point of the building
            target <- my_home.exit_point;
            do goto target: target;
            
            // If close enough to exit point, consider building exited
            if (location distance_to target < 0.5) {
                has_exited <- true;
                target <- evacuation_center.location;
            }
        } else {
            // After exiting, head to evacuation center
            do goto target: target;
            
            // Avoid buildings on fire by increasing speed
            list<building> nearby_burning <- building at_distance 10 where (each.is_on_fire);
            if (!empty(nearby_burning)) {
                // Run faster away from fire
                speed <- person_speed * 1.5;
            } else {
                speed <- person_speed;
            }
            
            // If arrived at evacuation center
            if (location distance_to evacuation_center.location < 2.0) {
                // Safely evacuated, now move inside the evacuation center
                location <- any_location_in(evacuation_center.shape);
                is_evacuating <- false;
                is_safe <- true;  // Mark as safe
                my_home <- evacuation_center; // Now living in evacuation center
                write "A person has safely evacuated to the evacuation center";
            }
        }
    }
    
    aspect default {
        if (is_dead) {
            draw circle(0.5) color: #black;
        } else {
            if (is_safe) {
                // Safely evacuated
                draw circle(0.5) color: #green;
            } else if (is_evacuating) {
                // Evacuating
                draw circle(0.5) color: has_exited ? #yellow : #red;
            } else {
                // Not evacuating yet
                draw circle(0.5) color: #blue;
            }
        }
    }
    
    // 3D representation for people
    aspect sphere {
        if (is_dead) {
            draw sphere(0.3) color: #black;
        } else {
            if (is_safe) {
                // Safely evacuated
                draw sphere(0.3) color: #green;
            } else if (is_evacuating) {
                // Evacuating
                draw sphere(0.3) color: has_exited ? #yellow : #red;
            } else {
                // Not evacuating yet
                draw sphere(0.3) color: #blue;
            }
        }
    }
}

// Define an experiment to visualize the elevated buildings and people
experiment evacuation_simulation type: gui {
    parameter "Start fire" var: fire_started category: "Fire";
    parameter "Fire spread probability" var: fire_spread_probability min: 0.05 max: 0.5 step: 0.05 category: "Fire";
    parameter "Fire spread radius" var: fire_spread_radius min: 5 max: 50 step: 5 category: "Fire";
    parameter "Person speed" var: person_speed min: 0.1 max: 1.0 step: 0.1 category: "People";
    
    output {
        // 2D display
        display map {
            species building aspect: default;
            species pathway aspect: default;
            species exit_indicator aspect: default;
            species fire aspect: default;
            species smoke aspect: default;
            species person aspect: default;
        }
        
        // 3D display with elevated buildings and people inside
        display map_3D type: opengl {
            species building aspect: elevated;
            species pathway aspect: elevated;
            species exit_indicator aspect: elevated;
            species fire aspect: elevated;
            species smoke aspect: default;
            species person aspect: sphere;
        }
        
        // Monitor the evacuation progress
        monitor "People safely evacuated" value: person count (each.my_home = evacuation_center);
        monitor "People still evacuating" value: person count (each.is_evacuating);
        monitor "People perished" value: person count (each.is_dead);
        monitor "Buildings on fire" value: building count (each.is_on_fire);
    }
}