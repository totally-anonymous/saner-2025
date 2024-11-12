#!/bin/bash

source analysis.conf

eval "$(/home/saner/anaconda3/bin/conda shell.bash hook)"
conda activate saner

# Post-process Kaiaulu data before the analysis.
# For the prior configuration, we only split the gitlog to slices for file information.
# For the replication configuration, we additionally match developer identities.
for project in ${project_list[*]}
  do
    echo "Processing data for project $project (Kaiaulu with prior configuration)..."
    python3 "$src_path"/process_kaiaulu.py \
      --experiment "prior" \
      --project "$project" \
      --data_path "$kaiaulu_raw_data_path/prior/$project" \
      --conf_path "$kaiaulu_path"/conf/"$project"_prior_analysis.yml \
      --save_path "$kaiaulu_data_path/prior/$project" \
      --time_slice > "$log_path"/process_kaiaulu_"$project"_prior.log

    echo "Processing data for project $project (Kaiaulu with replication configuration)..."
    python3 "$src_path"/process_kaiaulu.py \
      --experiment "replication" \
      --project "$project" \
      --data_path "$kaiaulu_raw_data_path/replication/$project" \
      --conf_path "$kaiaulu_path"/conf/"$project"_replication_analysis.yml \
      --save_path "$kaiaulu_data_path/replication/$project" \
      --merge_id \
      --time_slice > "$log_path"/process_kaiaulu_"$project"_replication.log
  done
