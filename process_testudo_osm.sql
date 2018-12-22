--------------------------------------------------------------------------------
---This script handles secondary processing of open street map data after it has
---been loaded into a spatialite databse. Tables are created that present the
---relevent data in a way that is easy to manipulate in other programming
---languages or in a GIS package such as QGIS.
--------------------------------------------------------------------------------

SELECT "Building testudo_statues table";

--Extract the locations and names of testudo statues into a new table.
CREATE TABLE testudo_statues AS
SELECT ROW_NUMBER() OVER(ORDER BY osm_nodes.node_id) AS n, osm_nodes.node_id, osm_nodes.Geometry, rtrim(substr(name.v, 10),')') AS name
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
          search_frame=Buffer(testudo.geometry, 0.01))
GROUP BY testudo.node_id
HAVING Min(Distance(testudo.geometry, network.geometry));

SELECT "Constructing network based voronoi diagram";

CREATE TABLE grid_net_testudo AS
SELECT net.p as grid_point, testudos.n, testudos.name
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

SELECT RecoverGeometryColumn('grid_net_testudo', 'grid_point', 4326, 'POINT');

CREATE TABLE network_voronoi AS
SELECT name, CastToMultiPolygon(SnapToGrid(ConcaveHull(ST_Collect(grid_point)), 0.0005)) AS g
FROM grid_net_testudo
GROUP BY n;

DELETE FROM network_voronoi WHERE g IS NULL;

SELECT RecoverGeometryColumn('network_voronoi', 'g', 4326, 'MULTIPOLYGON');

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
