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
