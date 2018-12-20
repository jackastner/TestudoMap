.PHONY: clean all publish

overpass = http://overpass-api.de/api/interpreter

data_basename = testudo_data
osm_file = $(data_basename).osm
db_file = $(data_basename).db
json_file = $(data_basename).json

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

$(db_file): init_osm_data process_testudo_osm.sql drop_testudo_data.sql
	cp $(db_file) $(db_file).bak
	spatialite -bail $(db_file) < drop_testudo_data.sql
	(spatialite -bail $(db_file) < process_testudo_osm.sql) || (rm --force $(db_file); cp $(db_file).bak $(db_file); rm --force $(db_file).bak; false)
	rm --force $(db_file).bak


$(json_file): $(db_file) make_geojson.sh
	./make_geojson.sh $(db_file) $(json_file)

clean:
	rm --force $(osm_file) $(db_file) $(json_file)
