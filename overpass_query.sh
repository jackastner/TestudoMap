#! /bin/bash

OVERPASS_INTERPRETER=$1
OSM_FILE=$2

# Download raw osm data through an instance of the overpass api
curl -d "@-" -X post $OVERPASS_INTERPRETER -o $OSM_FILE <<EOF
    area(3600133393)->.college_park;

    /*get testudo statues*/
    node
      [historic_landmark=testudo]
      (area.college_park);
    out;

    /*get campus bonderies*/
    way
      [wikidata=Q503415]
      (area.college_park);
      (._;>;);
    out;
EOF
