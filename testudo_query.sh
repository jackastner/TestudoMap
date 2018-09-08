#! /bin/sh

OVERPASS_INTERPRETER=http://overpass-api.de/api/interpreter

OUTPUT_BASENAME=testudo_data
OSM_FILE=$(mktemp --tmpdir $OUPUT_BASENAME.XXX.osm)
DB_FILE=$OUTPUT_BASENAME.db

if [ "$1" = "-f" ] || [ "$1" = "--force" ] ; then
    rm --force $DB_FILE
else 
    [ -f $DB_FILE ] && rm --interactive $DB_FILE
    [ -f $DB_FILE ] && { echo 'Cannot continue with out removing existing database file'; exit 1; }
fi

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

# Initial processing of data to load it into a spatialite database
spatialite_osm_raw --osm-path $OSM_FILE --db-path $DB_FILE

# Secondary processing to create usefull tables
spatialite $DB_FILE < process_testudo_osm.sql

rm $OSM_FILE
