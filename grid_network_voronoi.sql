DROP TABLE IF EXISTS grid_net_testudo;
DROP TABLE IF EXISTS network_voronoi;

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
