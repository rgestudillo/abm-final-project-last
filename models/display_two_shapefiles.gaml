/**
 * Display one shapefile: lahug.shp
 * Building 0 as evacuation site, spawn people who go there.
 */
model simple_display
global {
    file lahug_file <- file("../includes/lahug.shp");
    geometry shape <- envelope(lahug_file);
    building evacuation_site;
    
    init {
        create building from: lahug_file;
        evacuation_site <- building[0];
        
        // Spawn people randomly
        create people number: 50 {
            location <- any_location_in(shape);
        }
    }
}
species building {
    aspect default {
        if (self = evacuation_site) {
            draw shape color: #yellow border: #black;
            draw "Evacuation Site" at: location color: #red font: font("Arial", 12, #bold);
        } else {
            draw shape color: #gray border: #black;
        }
    }
}

species people skills: [moving] {
    point target;
    
    init {
        target <- evacuation_site.location;
    }
    
    reflex move {
        if (location distance_to target > 2.0) {
            do goto target: target speed: 2.0;
        }
    }
    
    aspect default {
        draw circle(1.5) color: #green border: #darkgreen;
    }
}
experiment main type: gui {
    output {
        display map {
            species building aspect: default;
            species people aspect: default;
        }
    }
}