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
spatialite $DB_FILE <<EOF
    --Extract the locations and names of testudo statues into a new table.
    CREATE TABLE testudo_statues AS
    SELECT osm_nodes.node_id, Geometry, rtrim(substr(name.v, 10),')') AS name
    FROM osm_nodes 
    INNER JOIN osm_node_tags AS landmark 
        ON (osm_nodes.node_id = landmark.node_id AND
            landmark.k='historic_landmark' AND
            landmark.v='testudo')
    INNER JOIN osm_node_tags AS name 
        ON (osm_nodes.node_id = name.node_id AND
            name.k='name');

    SELECT RecoverGeometryColumn('testudo_statues', 'Geometry', 4326, 'POINT');

    --Extract the polygon representing campus bounderies into a new table
    CREATE TABLE campus_geometry AS
    SELECT refs.way_id, MakePolygon(MakeLine(Geometry)) AS Geometry
    FROM osm_way_refs AS refs 
    INNER JOIN osm_way_tags AS tags 
        ON (tags.way_id=refs.way_id AND
            tags.k='wikidata'
            AND tags.v='Q503415') 
    INNER JOIN osm_nodes AS nodes 
        ON (nodes.node_id=refs.node_id) 
    ORDER BY refs.sub;

    SELECT RecoverGeometryColumn('campus_geometry', 'Geometry', 4326, 'POLYGON');

    --Contruct a table containing voronoi polygons for each testudo statue
    CREATE TABLE testudo_voronoi AS
    WITH 
        voronoi(multi) AS (
            SELECT VoronojDiagram(Collect(Geometry))
            FROM testudo_statues
        ),
        vals(n) AS (
            SELECT 1
            UNION ALL
            SELECT n+1 FROM vals
            LIMIT (SELECT NumGeometries(multi) FROM voronoi)
        )
    SELECT CastToMulti(Intersection(campus.Geometry, GeometryN(voronoi.multi, vals.n))) AS voronoi_region, testudos.node_id, testudos.name
    FROM vals 
    INNER JOIN voronoi
    INNER JOIN campus_geometry AS campus
    INNER JOIN testudo_statues AS testudos 
      WHERE (ST_Contains(voronoi_region, testudos.Geometry));

    SELECT RecoverGeometryColumn('testudo_voronoi', 'voronoi_region', 4326, 'MULTIPOLYGON');
EOF

rm $OSM_FILE
