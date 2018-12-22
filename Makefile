.PHONY: clean all publish histogram

overpass = http://overpass-api.de/api/interpreter

data_basename = testudo_data
osm_file = $(data_basename).osm
db_file = $(data_basename).db
json_file = $(data_basename).json
tif_file = $(data_basename).tif

webpage_dir = webpage
webpage_files = $(webpage_dir)/testudo_map.html $(webpage_dir)/testudo_map.css $(webpage_dir)/testudo_map.js

all: $(json_file)

publish: $(json_file) $(webpage_files) testudo_icon.svg
	scp $(json_file) testudo_icon.svg $(webpage_files) kastner@linux.grace.umd.edu:/users/kastner/pub/

$(osm_file): overpass_query.sh
	./overpass_query.sh $(overpass) $(osm_file)

init_osm_data: $(osm_file) init_osm_db.sh footpath_template
	-rm --force $(db_file)
	./init_osm_db.sh $(osm_file) $(db_file)
	touch init_osm_data

create_grid: init_osm_data create_grid.sql drop_grid.sql
	cp $(db_file) $(db_file).bak
	spatialite -bail $(db_file) < drop_grid.sql
	(spatialite -bail $(db_file) < create_grid.sql) || (rm --force $(db_file); cp $(db_file).bak $(db_file); rm --force $(db_file).bak; false)
	rm --force $(db_file).bak
	touch create_grid

process_testudo_osm: create_grid process_testudo_osm.sql drop_testudo_data.sql
	cp $(db_file) $(db_file).bak
	spatialite -bail $(db_file) < drop_testudo_data.sql
	(spatialite -bail $(db_file) < process_testudo_osm.sql) || (rm --force $(db_file); cp $(db_file).bak $(db_file); rm --force $(db_file).bak; false)
	rm --force $(db_file).bak
	touch process_testudo_osm

$(json_file): process_testudo_osm make_geojson.sh
	./make_geojson.sh $(db_file) $(json_file)

$(tif_file): process_testudo_osm
	gdal_rasterize -l grid_net_testudo\
	               -a n\
	               -tr 0.0005 0.0005\
	               -a_nodata 0.0\
	               -te -76.9616585 38.9810767 -76.930857 39.0028657\
	               -ot Byte\
	               -of GTiff\
	               $(db_file)\
	               $(tif_file)

histogram: $(tif_file) histogram.py
	./histogram.py $(tif_file)

clean:
	rm --force $(osm_file) $(db_file) $(json_file)
