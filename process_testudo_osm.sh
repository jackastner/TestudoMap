#! /bin/bash

OSM_FILE=$1
DB_FILE=$2

# Initial processing of data to load it into a spatialite database
spatialite_osm_raw --osm-path $OSM_FILE --db-path $DB_FILE

# Secondary processing to create usefull tables
spatialite $DB_FILE < process_testudo_osm.sql
