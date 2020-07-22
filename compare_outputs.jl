import JSON
using ArgParse


function read_json(filename)
  """ Return adjacency matrix and IDs from JSON file. """
  adj, ids = nothing, nothing
  open(filename, "r") do f
    out = JSON.parse(f)  # parse and transform data
    adj = out["adj"]
    adj = reduce(hcat, adj) # make into matrix
    ids = out["order"]
  end
  println("Successfully read JSON file from ", filename)
  return adj, ids
end


function check_adjacency(pyadj, jadj)
  """ Check that two adjacency matrices are identical
  """
  if pyadj == jadj
    println("Python and Julia adjacency matrices completely agree. Hooray!")
  else
    disagree_ids = []
    for i in 1:size(pyadj)[1]
      for j in i:size(pyadj)[1]
        if pyadj[i,j] != jadj[i, j]
          push!(disagree_ids, (i,j))
        end
      end
    end
    println("Total number of disagreements between Python and Julia (assuming symmetric adjacency matrix): ", length(disagree_ids))
  end
end


function compare_outputs(json_path_1, json_path_2)
  """ Compare the outputs of the Julia graph and the Python graph.
  """
  # check that the order of the blocks was the same
  adj1, ids1 = read_json(json_path_1)
  adj2, ids2 = read_json(json_path_2)
  if ids1 == ids2
    println("Order matches between Python and JSON.")
  else
    println("Uh oh, order is not matching up!")
  end
  check_adjacency(adj1, adj2)
end


s = ArgParseSettings()
@add_arg_table! s begin
    "--json1"
        help = "Path to first JSON output"
        arg_type = String
        required = true
    "--json2"
        help = "Path to second JSON output"
        arg_type = String
        required = true
end
parsed_args = parse_args(ARGS, s)

compare_outputs(parsed_args["json1"], parsed_args["json2"])
