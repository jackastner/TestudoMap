--------------------------------------------------------------------------------
---This script handles secondary processing of open street map data after it has
---been loaded into a spatialite databse. Tables are created that present the
---relevent data in a way that is easy to manipulate in other programming
---languages or in a GIS package such as QGIS.
--------------------------------------------------------------------------------

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
