#!/bin/bash

source analysis.conf

eval "$(/home/saner/anaconda3/bin/conda shell.bash hook)"
conda activate saner

# Prepare the developer networks constructed by each tool (configuration).
for project in ${project_list[*]}
do
  echo "Preparing developer networks for project $project (Codeface)..."
  # Prepare Codeface adjacency matrices for analysis.
  python3 "$src_path"/network_codeface.py \
    --port "$port" \
    --data_path "$codeface_data_path"/"$project"/"proximity" \
    --save_path "$network_path/codeface/$project"
done

eval "$(/home/saner/anaconda3/bin/conda shell.bash hook)"
conda activate kaiaulu

# Prepare the developer networks constructed by each tool (configuration).
for project in ${project_list[*]}
do
  echo "Constructing developer networks for project $project (Kaiaulu with prior configuration)"
  mkdir -p "$network_path"/kaiaulu/prior/"$project"
  i=1
  for d in "$kaiaulu_data_path"/prior/"$project"/entities/*
  do
    range=$(basename "${d}")
    Rscript "$kaiaulu_path"/exec/graph.R temporal entity \
      "$kaiaulu_path"/tools.yml \
      "$kaiaulu_path"/conf/"$project"_prior_analysis.yml \
      "$kaiaulu_path"/conf/"$project"_prior_cli.yml \
      "$d/"entities_"$range".csv \
      "$network_path"/kaiaulu/prior/"$project"/range_"$i"_adjacency_matrix.csv
    ((i++))
  done

  echo "Constructing developer networks for project $project (Kaiaulu with replication configuration)"
  mkdir -p "$network_path"/kaiaulu/replication/"$project"
  i=1
  for d in "$kaiaulu_data_path"/replication/"$project"/entities/*
  do
    range=$(basename "${d}")
    Rscript "$kaiaulu_path"/exec/graph.R temporal entity \
      "$kaiaulu_path"/tools.yml \
      "$kaiaulu_path"/conf/"$project"_replication_analysis.yml \
      "$kaiaulu_path"/conf/"$project"_replication_cli.yml \
      "$d/"entities_"$range".csv \
      "$network_path"/kaiaulu/replication/"$project"/range_"$i"_adjacency_matrix.csv
    ((i++))
  done
done

eval "$(/home/saner/anaconda3/bin/conda shell.bash hook)"
conda activate saner

# Plot Codeface and Kaiaulu networks for a qualitative comparison.
for project in ${project_list[*]}
do
  echo "Plotting developer networks for project $project..."
  # Qualitative comparison with adjacency plots
  i=1
  for d in "$network_path"/kaiaulu/prior/"$project"/*
  do
    r=$(basename "${d}" | tr -d -c 0-9)
    echo "$project range $r"
    if [ "$project" == "spark" ] && [ "$r" == 13 ]; then
      Rscript "$plot_path"/plot_network.R \
        --experiment "prior" --project "$project" --range "$r" \
        --adj_path_codeface "$network_path"/codeface/ \
        --adj_path_kaiaulu "$network_path"/kaiaulu/prior \
        --plot_path "$plot_path" --names --tikz
    else
      Rscript "$plot_path"/plot_network.R \
        --experiment "prior" --project "$project" --range "$r" \
        --adj_path_codeface "$network_path"/codeface/ \
        --adj_path_kaiaulu "$network_path"/kaiaulu/prior \
        --plot_path "$plot_path" --names
    fi
  done

  i=1
  for d in "$network_path"/kaiaulu/replication/"$project"/*
  do
    r=$(basename "${d}" | tr -d -c 0-9)
    echo "$project range $r"
    if [ "$project" == "spark" ] && [ "$r" == 13 ]; then
      Rscript "$plot_path"/plot_network.R \
        --experiment "replication" --project "$project" --range "$r" \
        --adj_path_codeface "$network_path"/codeface \
        --adj_path_kaiaulu "$network_path"/kaiaulu/replication \
        --plot_path "$plot_path" --names --tikz
    else
      Rscript "$plot_path"/plot_network.R \
        --experiment "replication" --project "$project" --range "$r" \
        --adj_path_codeface "$network_path"/codeface \
        --adj_path_kaiaulu "$network_path"/kaiaulu/replication \
        --plot_path "$plot_path" --names
    fi
  done
done

# Compare Codeface and Kaiaulu networks quantitatively.
echo "Comparing developer networks..."
python3 "$src_path"/network_comparison.py \
  --network_path_codeface "$network_path"/codeface \
  --network_path_kaiaulu "$network_path"/kaiaulu \
  --kaiaulu_conf_path "$kaiaulu_path"/conf \
  --save_path "$network_path"/comparison

# Report the analysis results.
echo "Creating network similarity table..."
Rscript "$plot_path"/plot_network_summary.R \
  --network_comparison_path "$network_path"/comparison \
  --plot_path "$plot_path"

cd "$plot_path" && bash "$plot_path"/gen_img.sh