BEGIN;

DROP TABLE IF EXISTS testudo_voronoi;

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

COMMIT;
