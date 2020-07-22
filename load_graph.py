from gerrychain import Graph
import numpy as np
import json
import time
from matplotlib import pyplot as plt
from shapely.geometry.polygon import LinearRing, Polygon
from shapely.geometry.multipolygon import MultiPolygon
import argparse

graph = None

def load_graph_from_shp(file_path, write_path, id_key, adjacency):
    global graph
    print("Loading graph...")
    start = time.perf_counter()
    graph = Graph.from_file(file_path, adjacency=adjacency)
    end = time.perf_counter()
    print("Took " + str((end-start)) + " seconds to create the graph.")
    print("This state has " + str(len(graph.nodes)) + " blocks")

    # write matrix
    adj_mat = np.zeros((len(graph.nodes), len(graph.nodes)))
    if id_key not in graph.nodes[0].keys():
        print(id_key, "not found in node attributes.")
        print("Attributes: ", graph.nodes[0].keys())
    ids = [graph.nodes[i][id_key] for i in range(len(graph.nodes))]
    for e in graph.edges:
        adj_mat[e[0], e[1]] = 1
        adj_mat[e[1], e[0]] = 1
    print("Writing adjacency matrix and IDs to file...")
    with open(write_path, 'w') as outfile:
        json.dump({"order": ids, "adj": adj_mat.tolist()}, outfile)
    print("Done! JSON written to " + write_path)

parser = argparse.ArgumentParser()
parser.add_argument("--shp_path", action="store", type=str, help="The path to the SHP file", required=True)
parser.add_argument("--adjacency", action="store", choices=["queen", "rook"], type=str, required=True)
parser.add_argument("--id_key", action="store", type=str, required=True, help="Unique identifier for each node in the graph")
parser.add_argument("--filename", action="store", type=str, required=True, help="Filename to save JSON (include .json)")
args = parser.parse_args()
print("Constructing a graph from", args.shp_path, "using", args.adjacency, "style adjacency, where blocks are uniquely identified by", args.id_key)
load_graph_from_shp(args.shp_path, args.filename, args.id_key, args.adjacency)
