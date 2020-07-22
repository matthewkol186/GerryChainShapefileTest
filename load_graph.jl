import JSON
using LibGEOS
using DataFrames
using Shapefile
using Plots
import LibSpatialIndex
using Random
using GeoInterface
using ArgParse

function construct_shape(coordinates)
  """ Given coordinates, constructs an array of Polygons for a particular block.
  """
  # get weird self-intersection error from LibGEOS if I try to make MultiPolygon,
  # so instead we will just create an array of Polygons
  return [LibGEOS.Polygon(c) for c in coordinates]
end


function construct_mbr(coordinates)
  """ Given coordinates, constructs a minimum bounding rectangle around the
      polygon(s). A rectangle is represented by ([lower_left_x, lower_left_y],
      [upper_right_x, upper_right_y]).
  """
  xmin = Inf
  ymin = Inf
  xmax = -Inf
  ymax = -Inf
  for c in coordinates # if this is a MultiPolygon, this will loop more than once
    for l in c
      points = reduce(hcat, l)
      xmin = minimum([xmin, minimum(points[1, :])])
      ymin = minimum([ymin, minimum(points[2, :])])
      xmax = maximum([xmax, maximum(points[1, :])])
      ymax = maximum([ymax, maximum(points[2, :])])
    end
  end
  return ([xmin, ymin], [xmax, ymax])
end


function any_queen_intersection(poly_array₁, poly_array₂)
  """ Returns true if there exists any queen intersection between a polygon
      in poly
  """
  for p₁ in poly_array₁
    for p₂ in poly_array₂
      inter = LibGEOS.intersection(p₁, p₂)
      if !LibGEOS.isEmpty(inter)
        return true
      end
    end
  end
  return false
end


function any_rook_intersection(poly_array₁, poly_array₂)
  """ Returns true if there exists any rook intersection between a polygon
      in poly
  """
  for p₁ in poly_array₁
    for p₂ in poly_array₂
      inter = LibGEOS.intersection(p₁, p₂)
      # criteria for rook intersection simply requires that there be a "shared
      # border", which means that the intersection must be lines, rather than
      # points
      if !LibGEOS.isEmpty(inter) && !(inter isa LibGEOS.Point || inter isa LibGEOS.MultiPoint)
        return true
      end
    end
  end
  return false
end


function adj_matrix_rtree(rows, poly, rtree, mbrs, adjacency; verbose=true)
  """ Constructs an adjacency matrix using the RTree.
  """
  adj_matrix = zeros(length(rows), length(rows))
  queen_adj = adjacency == "queen"
  for i in 1:length(rows)
    if verbose && (i-1) % 500 == 0
      println("On row ", i, "...")
    end
    # get all candidate nodes
    candidate_ids = LibSpatialIndex.intersects(rtree, mbrs[i][1], mbrs[i][2])
    for id in candidate_ids
      if id !== i # ignore edges to self
        if queen_adj && any_queen_intersection(poly[i], poly[id])
          adj_matrix[i,id] = 1
          adj_matrix[id,i] = 1
        elseif !queen_adj && any_rook_intersection(poly[i], poly[id])
          adj_matrix[i,id] = 1
          adj_matrix[id,i] = 1
        end
      end
    end
  end
  return adj_matrix
end


function adj_matrix_bruteforce(rows, poly, adjacency; verbose=true)
  """ Constructs an adjacency matrix by going through every block and
      testing for intersection with every other block.
  """
  adj_matrix = zeros(length(rows), length(rows))
  queen_adj = adjacency == "queen"
  for i in 1:length(rows)
    if verbose && (i-1) % 500 == 0
      println("On row ", i, "...")
    end
    for j in (i+1):length(rows)
      if queen_adj && any_queen_intersection(poly[i], poly[id])
        adj_matrix[i,id] = 1
        adj_matrix[id,i] = 1
      elseif !queen_adj && any_rook_intersection(poly[i], poly[id])
        adj_matrix[i,id] = 1
        adj_matrix[id,i] = 1
      end
    end
  end
  return adj_matrix
end


s = ArgParseSettings()
@add_arg_table! s begin
    "--adjacency"
        help = "Type of adjacency to use. Should be either \"rook\" or \"queen\""
        arg_type = String
        required = true
    "--prefix"
        help = "The path to the SHP/DBF files, minus the extension. e.g., VA_precincts/VA_precincts"
        arg_type = String
        required = true
    "--id_key"
        help = "The unique ID for each block"
        arg_type = String
        required = true
    "--filename"
        help = "Where to dump the resulting adjacency matrix & IDs"
        arg_type = String
        required = true
    "--bruteforce"
        help = "Whether to use the brute force method of creating the adjacency matrix instead of the RTree method"
        action = :store_true
    "--quiet"
        help = "Whether to print verbose output"
        action = :store_true
end
parsed_args = parse_args(ARGS, s)

path = parsed_args["prefix"] # extensions in folder should be .dbf, .shp
table = Shapefile.Table(path)
rows = collect(table)
coords = [LibGEOS.GeoInterface.coordinates(getfield(r, :geometry)) for r in rows]
poly = [construct_shape(c) for c in coords]


adj = nothing
if parsed_args["bruteforce"]
  adj = adj_matrix_bruteforce(rows, poly, parsed_args["adjacency"], verbose = !parsed_args["quiet"])
else
  mbrs = [construct_mbr(c) for c in coords]
  rtree = LibSpatialIndex.RTree(2) # RTree makes computation more efficient
  # insert an MBR for each polygon in the RTree
  for (i, mbr) in enumerate(mbrs)
    LibSpatialIndex.insert!(rtree, i, mbr[1], mbr[2])
  end
  adj = adj_matrix_rtree(rows, poly, rtree, mbrs, parsed_args["adjacency"], verbose = !parsed_args["quiet"])
end
ids = [getproperty(getfield(r, :record), Symbol(parsed_args["id_key"])) for r in rows]
data_dump = Dict("order" => ids, "adj" => adj)

# write to output file
open(parsed_args["filename"], "w") do f
    write(f, JSON.json(data_dump))
 end
