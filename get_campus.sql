BEGIN;

DROP TABLE IF EXISTS campus_geometry;

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

COMMIT;
