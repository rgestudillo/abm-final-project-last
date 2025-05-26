/**
* Name: abmproject
* Based on the internal empty template.
* Author: estud
* Tags:
*/

model abmproject

global {
    file pathway_shapefile <- file("../includes/pathway.shp");
    geometry shape <- envelope(pathway_shapefile);
    graph pathway_network;
    
    init {
        create pathway from: pathway_shapefile;
        pathway_network <- as_edge_graph(pathway);
        create people number: 5 {
            location <- any_location_in(one_of(pathway).shape);
        }
    }
}

species people skills: [moving] {
    float speed <- 1.0;
    path my_path;
    
    reflex walk_to_pathway0 {
        if my_path = nil {
            pathway target_pathway <- pathway[0];
            if target_pathway != nil {
                point target_location <- any_location_in(target_pathway.shape);
                my_path <- path_between(pathway_network, location, target_location);
            }
        }
        
        if my_path != nil {
            do follow path: my_path speed: speed;
            if location distance_to my_path.target < 2 {
                my_path <- nil;
            }
        }
    }
    
    aspect default {
        draw circle(2) color: #red;
    }
}

species pathway {
    aspect default {
        draw shape color: #blue;
    }
}

experiment main type: gui {
    output {
        display map {
            species pathway;
            species people;
        }
    }
}