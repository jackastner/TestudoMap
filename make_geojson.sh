#! /bin/bash

GEOJSON_FILE=testudo_data.json

TESTUDOS=$(spatialite testudo_data.db <<EOF
    SELECT printf('{"type": "Feature", "properties": {"name": "%s", "popupContent": "%s"}, "geometry": %s},', name, name, AsGeoJson(Geometry)) FROM testudo_statues;
EOF
)

VORONOI=$(spatialite testudo_data.db <<EOF
    SELECT printf('{"type": "Feature", "properties": {"name": "%s", "popupContent": "%s"}, "geometry": %s},', name, name, AsGeoJson(voronoi_region)) FROM testudo_voronoi;
EOF
)

echo -n '{"testudos": {"type": "FeatureCollection", "features": ['${TESTUDOS::-1}']},' > $GEOJSON_FILE
echo    ' "voronoi":  {"type": "FeatureCollection", "features": ['${VORONOI::-1}']}}' >> $GEOJSON_FILE
