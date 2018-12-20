#! /bin/bash

OSM_FILE=$1
DB_FILE=$2

# Initial processing of data to load it into a spatialite database
spatialite_osm_raw --osm-path $OSM_FILE --db-path $DB_FILE

# Build a network from the osm way data
spatialite_osm_net \
    --db-path $DB_FILE \
    --osm-path $OSM_FILE \
    --table network \
    --template-file footpath_template

# More network processing so that it can be used in
# a VirtualNetwork
spatialite_network \
    --db-path $DB_FILE \
    --table network \
    --from-column node_from \
    --to-column node_to \
    --geometry-column geometry \
    --output-table network_d \
    --virtual-table network_v \
    -c length \
    --overwrite-output

# Secondary processing to create usefull tables
spatialite -bail $DB_FILE < process_testudo_osm.sql
