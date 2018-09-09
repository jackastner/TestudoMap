#! /bin/bash

GEOJSON_FILE=testudo_data.json

TESTUDOS=$(spatialite testudo_data.db <<EOF
    SELECT printf('{"type": "Feature", "properties": {"name": "%s"}, "geometry": %s},', name, name, AsGeoJson(Geometry)) FROM testudo_statues;
EOF
)

VORONOI=$(spatialite testudo_data.db <<EOF
    SELECT printf('{"type": "Feature", "properties": {"name": "%s"}, "geometry": %s},', name, name, AsGeoJson(voronoi_region)) FROM testudo_voronoi;
EOF
)

echo -n '{"testudos": ['${TESTUDOS::-1}'],' > $GEOJSON_FILE
echo    ' "voronoi":  ['${VORONOI::-1}']}' >> $GEOJSON_FILE
