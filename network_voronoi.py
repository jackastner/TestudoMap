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
          (edge_id, testudo_id)
          """
    cursor.execute(sql)

def drop_search_table(cursor):
    sql = """
          DROP TABLE IF EXISTS network_search
          """
    cursor.execute(sql)

def insert_search_node(cursor, node, testudo):
    sql = """
          INSERT INTO network_search
          VALUES (?, ?)
          """
    cursor.execute(sql, [node, testudo]);

def insert_search(cursor, visited_map):
    for (n, (t, _)) in visited_map.items():
        insert_search_node(cursor, n ,t)

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

def drop_edge_table(cursor):
    sql = """
          DROP TABLE IF EXISTS edge_search;
          DROP TABLE IF EXISTS wft;
          """
          
    c.executescript(sql)

# This should be incorperated into the main search function since it's
# very inefficient as is.
def create_edge_table(cursor):
    sql = """
          CREATE TABLE edge_search AS
          SELECT net.id AS edge_id, stat.node_id AS testudo_id
          FROM network net,
               testudo_statues stat,
               network_search search,
               network_search search2
          WHERE search.testudo_id = stat.node_id AND
                search2.testudo_id = stat.node_id AND
                net.node_from = search.edge_id AND
                net.node_to = search2.edge_id;

          CREATE TABLE wft
          AS SELECT search.testudo_id, search.edge_id, net.geometry
          FROM edge_search search,
               network net 
          WHERE search.edge_id = net.id;

          SELECT RecoverGeometryColumn('wft', 'geometry', 4326, 'LINESTRING');
          """
    c.executescript(sql)



def network_search(cursor):

    # search will be started at the same time at the testudo statues
    initial_nodes = get_testudo_network_nodes(cursor)

    # associates a node if with a testudo statue id and distance to the statue
    # node_id -> (testudo_id, dist)
    visited_map = {}
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
                heapq.heappush(heap, (new_d, n))

    return visited_map


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

drop_edge_table(c)

t0 = time.time();
create_edge_table(c)
t1 = time.time();

print('search mapped to edges in ' + str(t1-t0))

conn.commit()
conn.close()
