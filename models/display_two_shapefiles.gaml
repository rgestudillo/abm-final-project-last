/**
 * Display two shapefiles with a simple evacuation example.
 * lahug.shp defines the world bounds. People spawn on the left
 * and move toward the shape from pathway.shp used as an
 * evacuation area.
 */

model simple_display

global {
    file lahug_file <- file("../includes/lahug.shp");
    file pathway_file <- file("../includes/pathway.shp");

    // Bounding box of the model is based on lahug.shp
    geometry lahug_bounds <- envelope(lahug_file);
    geometry evac_area <- envelope(pathway_file);
    geometry shape <- lahug_bounds;

    int nb_people <- 20;

    init {
        create building from: lahug_file;
        create evac_zone from: pathway_file;

        // Spawn people within the left half of the bounding box
        list<float> bbox <- lahug_bounds.bounds; // [min_x, min_y, max_x, max_y]
        float min_x <- bbox[0];
        float min_y <- bbox[1];
        float max_x <- bbox[2];
        float max_y <- bbox[3];
        float mid_x <- (min_x + max_x) / 2.0;

        create person number: nb_people {
            location <- { rnd(mid_x - min_x) + min_x,
                           rnd(max_y - min_y) + min_y };
            target <- centroid(evac_area);
            speed <- 1.0;
        }
    }
}

species building {
    aspect default {
        draw shape color: #gray border: #black;
    }
}

species evac_zone {
    aspect default {
        draw shape color: #blue width: 2;
    }
}

species person skills: [moving] {
    point target;

    reflex go_to_site {
        do goto target: target;
    }

    aspect default {
        draw circle(0.5) color: #green;
    }
}

experiment main type: gui {
    output {
        display map {
            species building aspect: default;
            species evac_zone aspect: default;
            species person aspect: default;
        }
    }
}
