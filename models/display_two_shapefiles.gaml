/**
 * Display two shapefiles: lahug.shp and pathway.shp
 * Minimal example for viewing GIS data.
 */

model simple_display

global {
    file lahug_file <- file("../includes/lahug.shp");
    file pathway_file <- file("../includes/pathway.shp");
    geometry shape <- envelope(lahug_file) + envelope(pathway_file);

    init {
        create building from: lahug_file;
        create pathway from: pathway_file;
    }
}

species building {
    aspect default {
        draw shape color: #gray border: #black;
    }
}

species pathway {
    aspect default {
        draw shape color: #blue width: 2;
    }
}

experiment main type: gui {
    output {
        display map {
            species building aspect: default;
            species pathway aspect: default;
        }
    }
}
