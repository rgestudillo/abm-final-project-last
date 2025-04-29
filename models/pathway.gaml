/**
 * Pathway Visualization Model
 * Author: estud
 * Tags: evacuation, GIS, pathway
 */

model pathway_evacuation

global {
    // Load the pathway shapefile
    file pathway_shape_file <- file("../includes/pathway.shp") parameter: "Pathway Shapefile" category: "GIS";

    // Define the geographical bounds based on the pathway shapefile
    geometry shape <- envelope(pathway_shape_file);

    init {
        // Create pathway agents from the shapefile
        create pathway from: pathway_shape_file;
        write "Total pathway segments loaded: " + length(pathway);
    }
}

// Define a species for pathways
species pathway {
    // Default 2D aspect
    aspect default {
        draw shape color: #blue width: 3;
    }
    
    // 3D aspect using a different approach
    aspect elevated {
        draw shape color: #blue width: 3;
    }
}

// Experiment to visualize pathways
experiment pathway_visualization type: gui {
    output {
        // 2D display
        display map {
            species pathway aspect: default;
        }
        
        // 3D display
        display map_3D type: opengl {
            species pathway aspect: elevated;
        }
    }
}