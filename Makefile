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

$(osm_file):
	./overpass_query.sh $(overpass) $(osm_file)

$(db_file): $(osm_file)
	-rm --force $(db_file)
	./process_testudo_osm.sh $(osm_file) $(db_file)

$(json_file): $(db_file)
	./make_geojson.sh $(db_file) $(json_file)

clean:
	rm --force $(osm_file) $(db_file) $(json_file)
