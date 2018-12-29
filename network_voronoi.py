import sys
import time

import sqlite3
import heapq

def init_spatialite(connection):
    connection.enable_load_extension(True)
    sql = """
          SELECT load_extension("mod_spatialite");
          """
    connection.execute(sql)

def testudo_for_id(cursor, testudo_id):
    sql = """
          SELECT name
          FROM testudo_statues
          WHERE node_id = ?
          """

    return cursor.execute(sql, [testudo_id]).fetchone()[0]

def create_search_table(cursor):
    sql = """
          CREATE TABLE network_search
          (edge_id, geometry, testudo_id)
          """
    cursor.execute(sql)

def drop_search_table(cursor):
    sql = """
          DROP TABLE IF EXISTS network_search
          """
    cursor.execute(sql)

def insert_search_node(cursor, node_to, node_from, testudo):
    sql = """
          INSERT INTO network_search
              SELECT id, geometry, ?
              FROM network
              WHERE (node_to = ? AND node_from = ?) OR
                    (node_to = ? AND node_from = ?)
          """
    cursor.execute(sql, [testudo, node_to, node_from, node_from, node_to]);

def insert_search(cursor, edge_map):
    for ((n0, n1), t) in edge_map.items():
        insert_search_node(cursor, n0, n1, t)

    sql = """
          SELECT RecoverGeometryColumn('network_search', 'geometry', 4326, 'LINESTRING');
          """
    cursor.execute(sql)

def get_edges(cursor, node_from):
    sql = """
          SELECT node_to, length
          FROM network
          WHERE node_from = ?

          UNION

          SELECT node_from, length
          FROM network
          WHERE node_to = ?
          """
    return cursor.execute(sql, [node_from, node_from]).fetchall()

def get_testudo_network_nodes(cursor):
    sql = """
          SELECT testudo_id, network_id
          FROM testudo_network_nodes
          """
    return cursor.execute(sql).fetchall()

def network_search(cursor):

    # search will be started at the same time at the testudo statues
    initial_nodes = get_testudo_network_nodes(cursor)

    # associates a node if with a testudo statue id and distance to the statue
    # node_id -> (testudo_id, dist)
    visited_map = {}

    #associate edges (pairs of nodes) with a testudo statue.
    # (node_id, node_id) -> testudo_id
    visited_edges = {}

    heap = []

    # populate data structures so that each testudo is in the queue and is
    # marked visited with d = 0.
    for (t, n) in initial_nodes:
        heapq.heappush(heap, (0, n))
        visited_map[n] = (t,0)

    while len(heap):

        (_, current) = heapq.heappop(heap)
        current_assoc = visited_map[current]

        # add each adjacent node to the queue if it has not been visited or it
        # has been visited but, at a higher cost.
        edges = get_edges(cursor, current)

        for (n, c) in edges:
            new_d = current_assoc[1] + c
            if (not (n in visited_map)) or (new_d < visited_map[n][1]):
                visited_map[n] = (current_assoc[0], new_d)
                visited_edges[current,n] = current_assoc[0]
                heapq.heappush(heap, (new_d, n))

    return visited_edges


db_file = sys.argv[1]
conn = sqlite3.connect(db_file)
init_spatialite(conn)
c = conn.cursor()

t0 = time.time();
search_result = network_search(c)
t1 = time.time();

print('search done in ' + str(t1-t0))

drop_search_table(c)
create_search_table(c)

t0 = time.time();
insert_search(c, search_result)
t1 = time.time();

print('insert done in ' + str(t1-t0))

conn.commit()
conn.close()
