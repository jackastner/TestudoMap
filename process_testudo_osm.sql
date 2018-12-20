--------------------------------------------------------------------------------
---This script handles secondary processing of open street map data after it has
---been loaded into a spatialite databse. Tables are created that present the
---relevent data in a way that is easy to manipulate in other programming
---languages or in a GIS package such as QGIS.
--------------------------------------------------------------------------------

SELECT "Building testudo_statues table";

--Extract the locations and names of testudo statues into a new table.
CREATE TABLE testudo_statues AS
SELECT osm_nodes.node_id, osm_nodes.Geometry, rtrim(substr(name.v, 10),')') AS name
FROM osm_nodes
INNER JOIN osm_node_tags AS landmark
    ON (osm_nodes.node_id = landmark.node_id AND
        landmark.k='historic_landmark' AND
        landmark.v='testudo')
INNER JOIN osm_node_tags AS name
    ON (osm_nodes.node_id = name.node_id AND
        name.k='name');

SELECT RecoverGeometryColumn('testudo_statues', 'Geometry', 4326, 'POINT');

SELECT "Building network_node testudo_node mapping";

--Associate each testudo statues with a the closest network node
CREATE TABLE testudo_network_nodes AS
SELECT testudo.node_id as testudo_id, network.node_id as network_id
FROM network_nodes AS network
INNER JOIN testudo_statues AS testudo
WHERE network.node_id IN (
    SELECT ROWID
    FROM SpatialIndex
    WHERE f_table_name='network_nodes' AND
          search_frame=Buffer(testudo.geometry, 0.001))
GROUP BY testudo.node_id
HAVING Min(Distance(testudo.geometry, network.geometry));

SELECT "Extracting campus geometry into campus_geometry table";

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

SELECT "Constructing network overlay latice";

CREATE TABLE grid_points AS
WITH
    grid(multi) AS (
        SELECT SquareGrid(Geometry, 0.001)
        FROM campus_geometry
    ),
    grid_idx(n) AS (
        SELECT 1
        UNION ALL
        SELECT n+1 FROM grid_idx
        LIMIT (SELECT NumGeometries(multi) FROM grid)
    )
SELECT grid_idx.n, Centroid(GeometryN(grid.multi, grid_idx.n)) AS p
FROM grid_idx, grid;

CREATE TABLE grid_net_points AS
SELECT grid_points.n, grid_points.p, network.node_id
FROM network_nodes AS network
INNER JOIN grid_points
WHERE network.node_id IN (
    SELECT ROWID
    FROM SpatialIndex
    WHERE f_table_name='network_nodes' AND
          search_frame=Buffer(grid_points.p, 0.001))
GROUP BY grid_points.n
HAVING Min(Distance(grid_points.p, network.geometry));

SELECT "Constructing network based voronoi diagram";

CREATE TABLE network_voronoi AS
SELECT net.p as grid_point, testudo_net.testudo_id, testudos.name
FROM grid_net_points net,
     testudo_statues testudos,
     testudo_network_nodes testudo_net
WHERE testudos.node_id=testudo_net.testudo_id
GROUP BY net.n
HAVING MIN((
    SELECT Cost
    FROM network_v
    WHERE NodeFrom=net.node_id AND
          NodeTo=testudo_net.network_id
    LIMIT 1
));

SELECT RecoverGeometryColumn('network_voronoi', 'grid_point', 4326, 'POINT');

SELECT "Constructing traditional voronoi diagram";

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
FROM vals,
     voronoi,
     campus_geometry campus,
     testudo_statues testudos
WHERE (ST_Contains(voronoi_region, testudos.Geometry));

SELECT RecoverGeometryColumn('testudo_voronoi', 'voronoi_region', 4326, 'MULTIPOLYGON');
