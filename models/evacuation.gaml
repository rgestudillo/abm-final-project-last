/**
* Name: evacuation
* Based on the internal empty template.
* Author: estud
* Tags: evacuation, GIS, Lahug
*/

model evacuation

global {
    // Load the shapefile
    file shape_file_name <- file("../includes/lahug.shp") parameter: "Shapefile to load:" category: "GIS specific";
    
    // Define the geographical bounds for the simulation based on the shapefile
    geometry shape <- envelope(shape_file_name);
    
    // Parameter for building heights
    float min_height <- 2.0 parameter: "Minimum building height:" category: "Buildings";
    float max_height <- 5.0 parameter: "Maximum building height:" category: "Buildings";
    
    init {
        // Create building agents from the shapefile
        create building from: shape_file_name {
            // Assign random heights to buildings, between min and max
            height <- rnd(min_height, max_height);
        }
        write "Shapefile loaded successfully with " + length(building) + " buildings.";
    }
}

// Define a species for the buildings with height
species building {
    float height;
    
    aspect default {
        draw shape color: #gray border: #black;
    }
    
    // 3D aspect for buildings with elevation
    aspect elevated {
        draw shape depth: height color: #gray border: #black;
    }
}

// Define an experiment to visualize the elevated buildings
experiment display_buildings type: gui {
    output {
        // 2D display
        display map {
            species building aspect: default;
        }
        
        // 3D display with elevated buildings
        display map_3D type: opengl {
            species building aspect: elevated;
        }
    }
}