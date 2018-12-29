DROP TABLE IF EXISTS grid_points;
DROP TABLE IF EXISTS grid_net_points;

SELECT "Constructing network overlay latice";

CREATE TABLE grid_points AS
WITH
    grid(multi) AS (
        SELECT SquareGrid(Geometry, 0.0005)
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
          search_frame=Buffer(grid_points.p, 0.01))
GROUP BY grid_points.n
HAVING Min(Distance(grid_points.p, network.geometry));
