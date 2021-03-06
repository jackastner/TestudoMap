.PHONY: clean all histogram

init_osm_data = .init_osm_data
create_grid = .create_grid
process_testudo_osm = .process_testudo_osm
get_campus = .get_campus
grid_network_voronoi = .grid_network_voronoi
simple_voronoi = .simple_voronoi
vector_network_voronoi = .vector_network_voronoi

empty_rules = $(init_osm_data) $(create_grid) $(process_testudo_osm) $(get_campus) $(grid_network_voronoi) $(simple_voronoi) $(vector_network_voronoi)

overpass = http://overpass-api.de/api/interpreter

data_dir = data
data_basename = $(data_dir)/testudo_data
osm_file = $(data_basename).osm
db_file = $(data_basename).db
json_file = $(data_basename).js
tif_file = $(data_basename).tif

data_files = $(osm_file) $(db_file) $(json_file) $(tif_file)

all: $(json_file) $(tif_file) $(vector_network_voronoi)

$(data_dir):
	mkdir -p $(data_dir)

$(osm_file): overpass_query.sh | $(data_dir)
	./overpass_query.sh $(overpass) $(osm_file)

$(init_osm_data): $(osm_file) init_osm_db.sh footpath_template
	-rm --force $(db_file)
	./init_osm_db.sh $(osm_file) $(db_file)
	touch $(init_osm_data)

$(get_campus): $(init_osm_data) get_campus.sql
	spatialite -bail $(db_file) < get_campus.sql
	touch $(get_campus)

$(create_grid): $(get_campus) create_grid.sql
	spatialite -bail $(db_file) < create_grid.sql
	touch $(create_grid)

$(process_testudo_osm): $(init_osm_data) process_testudo_osm.sql
	spatialite -bail $(db_file) < process_testudo_osm.sql
	touch $(process_testudo_osm)

$(grid_network_voronoi): $(create_grid) $(process_testudo_osm)
	spatialite -bail $(db_file) < grid_network_voronoi.sql
	touch $(grid_network_voronoi)

$(simple_voronoi): $(process_testudo_osm) $(get_campus)
	spatialite -bail $(db_file) < simple_voronoi.sql
	touch $(simple_voronoi)

$(vector_network_voronoi): $(process_testudo_osm) network_voronoi.py
	python network_voronoi.py $(db_file)
	touch $(vector_network_voronoi)

$(json_file): $(simple_voronoi) make_geojson.sh | $(data_dir) 
	./make_geojson.sh $(db_file) $(json_file)

$(tif_file): $(grid_network_voronoi) | $(data_dir)
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
	rm --force $(data_files) $(empty_rules)
	rmdir $(data_dir)
