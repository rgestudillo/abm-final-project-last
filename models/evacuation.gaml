/**
* Name: finalest
* Based on the internal empty template. 
* Author: 
* Tags: 
*/

model finalest

global {
    // Load the building shapefile
    file building_shapefile <- file("../includes/pinakafinal.shp") parameter: "Building Shapefile:" category: "GIS specific";
    
    // Define the geographical bounds for the simulation based on the shapefile
    geometry shape <- envelope(building_shapefile);
    
    // Evacuation center reference
    building evacuation_center;
    
    init {
        // Create building agents from building shapefile
        create building from: building_shapefile;
        
        // Set the first building as evacuation center
        evacuation_center <- building at 0;
        
        // Set building types
        ask building {
            if (self = evacuation_center) {
                building_type <- "evacuation_site";
                write "Evacuation center set: " + name;
            } else {
                building_type <- "house";
            }
        }
        
        // Spawn 5 people per house (not evacuation site)
        ask building where (each.building_type = "house") {
            create people number: 5 {
                // Spawn people randomly in the world
                location <- any_location_in(world.shape);
                my_house <- myself;
                target <- evacuation_center;
            }
        }
        
        write "Total people created: " + length(people);
    }
}

// Building species
species building {
    string building_id;
    string building_type <- "house";
    
    aspect default {
        // Color based on building type
        rgb building_color <- (building_type = "evacuation_site") ? #red : #blue;
        
        // Draw building
        draw shape color: building_color border: #black width: 1;
        
        // Draw label - make evacuation site label more prominent
        if (building_type = "evacuation_site") {
            draw "EVACUATION SITE" size: 15 color: #white at: location + {0, 10};
            draw building_id size: 10 color: #yellow at: location + {0, -5};
        } else {
            draw "House" size: 10 color: #white at: location + {0, 5};
        }
    }
}

// People species
species people skills: [moving] {
    building my_house;
    building target;
    float speed <- 2.0;
    bool reached_evacuation <- false;
    bool has_exited <- false;
    point exit_point;
    
    // Set exit point when person is created
    reflex set_exit when: exit_point = nil and my_house != nil {
        exit_point <- any_location_in(my_house.shape.contour);
    }
    
    reflex move when: target != nil and !reached_evacuation {
        // Check if reached evacuation site
        if (location distance_to target.location < 5.0) {
            reached_evacuation <- true;
            write "Person reached evacuation site!";
        } else {
            // Two-phase movement: first exit building, then go to evacuation center
            point movement_target;
            
            if (!has_exited) {
                // Phase 1: Move to building exit
                movement_target <- exit_point;
                
                // Move toward exit (can move freely inside own building)
                do goto target: movement_target;
                
                // Check if reached exit
                if (location distance_to exit_point < 1.0) {
                    has_exited <- true;
                    write "Person exited building";
                }
            } else {
                // Phase 2: Move to evacuation center with obstacle avoidance
                movement_target <- target.location;
                
                // Calculate next position based on movement toward target
                float target_heading <- self towards movement_target;
                point next_location <- location + {speed * cos(target_heading), speed * sin(target_heading)};
                
                // Check if next location would be inside a building
                bool would_collide <- false;
                ask building where (each.building_type = "house") {
                    if (next_location overlaps shape) {
                        would_collide <- true;
                    }
                }
                
                if (!would_collide) {
                    // Safe to move toward target
                    do goto target: movement_target;
                } else {
                    // Try to go around the obstacle
                    // First try turning left
                    float left_heading <- target_heading - 90;
                    point left_location <- location + {speed * cos(left_heading), speed * sin(left_heading)};
                    
                    bool left_blocked <- false;
                    ask building where (each.building_type = "house") {
                        if (left_location overlaps shape) {
                            left_blocked <- true;
                        }
                    }
                    
                    if (!left_blocked) {
                        heading <- left_heading;
                        do move;
                    } else {
                        // Try turning right
                        float right_heading <- target_heading + 90;
                        point right_location <- location + {speed * cos(right_heading), speed * sin(right_heading)};
                        
                        bool right_blocked <- false;
                        ask building where (each.building_type = "house") {
                            if (right_location overlaps shape) {
                                right_blocked <- true;
                            }
                        }
                        
                        if (!right_blocked) {
                            heading <- right_heading;
                            do move;
                        } else {
                            // Both sides blocked, try random direction
                            heading <- rnd(360.0);
                            do move;
                        }
                    }
                }
            }
        }
    }
    
    aspect default {
        // Color based on status
        rgb people_color;
        if (reached_evacuation) {
            people_color <- #green;
        } else if (has_exited) {
            people_color <- #yellow;
        } else {
            people_color <- #orange;
        }
        
        // Draw person as much smaller circle
        draw circle(0.3) color: people_color border: #black;
        
        // Draw connection line to target if not reached
        if (!reached_evacuation and target != nil) {
            point line_target <- has_exited ? target.location : exit_point;
            draw line([location, line_target]) color: #gray width: 0.2;
        }
    }
}

experiment finalest_simulation type: gui {
    output {
        display main_display {
            // Display buildings
            species building aspect: default;
            
            // Display people
            species people aspect: default;
        }
    }
}