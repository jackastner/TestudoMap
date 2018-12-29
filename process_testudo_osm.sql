--------------------------------------------------------------------------------
---This script handles secondary processing of open street map data after it has
---been loaded into a spatialite databse. Tables are created that present the
---relevent data in a way that is easy to manipulate in other programming
---languages or in a GIS package such as QGIS.
--------------------------------------------------------------------------------

DROP TABLE IF EXISTS testudo_statues;
DROP TABLE IF EXISTS testudo_network_nodes;

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
