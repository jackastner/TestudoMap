#! /bin/bash

DB_FILE=$1
GEOJSON_FILE=$2

TESTUDOS=$(spatialite $DB_FILE <<EOF
    SELECT printf('{"type": "Feature", "properties": {"name": "%s"}, "geometry": %s},', name, AsGeoJson(Geometry)) FROM testudo_statues;
EOF
)

VORONOI=$(spatialite $DB_FILE <<EOF
    SELECT printf('{"type": "Feature", "properties": {"name": "%s"}, "geometry": %s},', name, AsGeoJson(voronoi_region)) FROM testudo_voronoi;
EOF
)

echo -n '{"testudos": ['${TESTUDOS::-1}'],' > $GEOJSON_FILE
echo    ' "voronoi":  ['${VORONOI::-1}']}' >> $GEOJSON_FILE
