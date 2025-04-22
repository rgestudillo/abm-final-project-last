/**
* Name: evacuation
* Based on the internal empty template.
* Author: estud
* Tags: evacuation, GIS, Lahug
*/

model evacuation

global {
    // Load the shapefile
    file shape_file_name <- file("../includes/final.shp") parameter: "Shapefile to load:" category: "GIS specific";
    
    // Define the geographical bounds for the simulation based on the shapefile
    geometry shape <- envelope(shape_file_name);
    
    // Parameter for building heights
    float min_height <- 2.0 parameter: "Minimum building height:" category: "Buildings";
    float max_height <- 5.0 parameter: "Maximum building height:" category: "Buildings";
    
    // Parameter for number of people
    int nb_people_per_building <- 5 parameter: "Number of people per building:" category: "People";
    
    // Parameters for evacuation
    bool evacuation_started <- false parameter: "Start evacuation" category: "Evacuation";
    float person_speed <- 1.0 parameter: "Person speed" category: "People";
    
    // Keep track of the evacuation center
    building evacuation_center;
    
    init {
        // Create building agents from the shapefile
        create building from: shape_file_name {
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
        write "Shapefile loaded successfully with " + length(building) + " buildings.";
        
        // Set building0 as the evacuation center
        evacuation_center <- building at 0;
        ask evacuation_center {
            name <- "building0";
            is_evacuation_center <- true;
        }
        write "Evacuation center established at building0";
        
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
    
    // Action to start the evacuation process
    reflex manage_evacuation when: evacuation_started {
        ask person {
            is_evacuating <- true;
        }
    }
}

// Define a species for the buildings with height
species building {
    float height;
    bool is_evacuation_center <- false; // Flag for evacuation center
    point exit_point;  // The exit point for this building
    
    aspect default {
        draw shape color: is_evacuation_center ? #yellow : #gray border: #black;
    }
    
    // 3D aspect for buildings with elevation and transparency
    aspect elevated {
        // Choose color based on whether it's the evacuation center
        rgb wall_color <- is_evacuation_center ? rgb(255, 255, 0, 200) : rgb(150, 150, 150, 200);
        rgb roof_color <- is_evacuation_center ? rgb(255, 255, 0, 50) : rgb(200, 200, 200, 50);
        
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
    
    // Evacuation behavior
    reflex evacuate when: is_evacuating {
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
            
            // If arrived at evacuation center
            if (location distance_to evacuation_center.location < 2.0) {
                // Safely evacuated, now move inside the evacuation center
                location <- any_location_in(evacuation_center.shape);
                is_evacuating <- false;
                my_home <- evacuation_center; // Now living in evacuation center
                write "A person has safely evacuated to the evacuation center";
            }
        }
    }
    
    aspect default {
        draw circle(0.5) color: is_evacuating ? (has_exited ? #green : #red) : #blue;
    }
    
    // 3D representation for people
    aspect sphere {
        draw sphere(0.3) color: is_evacuating ? (has_exited ? #green : #red) : #blue;
    }
}

// Define an experiment to visualize the elevated buildings and people
experiment evacuation_simulation type: gui {
    parameter "Start evacuation" var: evacuation_started category: "Evacuation";
    
    output {
        // 2D display
        display map {
            species building aspect: default;
            species exit_indicator aspect: default;
            species person aspect: default;
        }
        
        // 3D display with elevated buildings and people inside
        display map_3D type: opengl {
            species building aspect: elevated;
            species exit_indicator aspect: elevated;
            species person aspect: sphere;
        }
        
        // Monitor the evacuation progress
        monitor "People safely evacuated" value: person count (each.my_home = evacuation_center);
        monitor "People still evacuating" value: person count (each.is_evacuating);
    }
}