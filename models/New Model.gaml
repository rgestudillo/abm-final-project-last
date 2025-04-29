	/**
	* Name: Luneray's flu 3
	* Author: Patrick Taillandier
	* Description: Importation of GIS data
	* Tags: gis, tutorial
	*/
	
	model model3
	
	global {
	    file roads_shapefile <- file("../includes/path2.shp");
	    file buildings_shapefile <- file("../includes/final3.shp");
	    geometry shape <- envelope(buildings_shapefile);
	
	    init {
	        create road from: roads_shapefile;
	        create building from: buildings_shapefile;
	        
	        // Debug information
	        write "Number of roads created: " + length(road);
	        write "Number of buildings created: " + length(building);
	        write "World bounds: " + shape;
	    }
	}
	
	species road {
	    aspect geom {
	        draw shape color: #black width: 2.0; // Increased width for better visibility
	    }
	}
	
	species building {
	    aspect geom {
	        draw shape color: #gray;
	    }
	}
	
	experiment main type: gui {
	    output {
	        display map {
	            species building aspect: geom; // Building layer first (background)
	            species road aspect: geom;     // Road layer on top for better visibility
	        }
	    }
	}