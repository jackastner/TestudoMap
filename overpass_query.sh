#! /bin/bash

OVERPASS_INTERPRETER=$1
OSM_FILE=$2

# Download raw osm data through an instance of the overpass api
curl -d "@-" -X post $OVERPASS_INTERPRETER -o $OSM_FILE <<EOF
    area(3600133393)->.college_park;

    node(area.college_park);
    out body;

    way(area.college_park);
    out body;
EOF
