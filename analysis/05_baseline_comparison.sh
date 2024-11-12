#!/bin/bash

source analysis.conf

eval "$(/home/saner/anaconda3/bin/conda shell.bash hook)"
conda activate saner

# Calculate statistics of the baseline data for each project and tool configuration.
for project in ${project_list[*]}
  do
    echo "Calculating statistics for project $project (Codeface)..."
    python3 "$src_path"/statistics_codeface.py \
      --port 3306 \
      --project "$project" \
      --count --count_save_path "$statistics_path/codeface" \
      --hashes --hash_save_dir_path "$hash_path/codeface/$project" \
      --rank --rank_save_dir_path "$rank_path/codeface/$project"
  done

for project in ${project_list[*]}
  do
    echo "Calculating statistics for project $project (Kaiaulu with prior configuration)"
    python3 "$src_path"/statistics_kaiaulu.py \
      --experiment "prior" \
      --project "$project" \
      --data_path "$kaiaulu_data_path/prior/$project" \
      --conf_path "$kaiaulu_path/conf/${project}_prior_analysis.yml" \
      --count --count_save_path "$statistics_path/kaiaulu/prior" \
      --hashes --hash_save_dir_path "$hash_path/kaiaulu/prior/$project" \
      --rank --rank_save_dir_path "$rank_path/kaiaulu/prior/$project" \
      > "$log_path"/statistics_kaiaulu_"$project"_prior.log

    echo "Calculating statistics for project $project (Kaiaulu with replication configuration)"
    python3 "$src_path"/statistics_kaiaulu.py \
      --experiment "replication" \
      --project "$project" \
      --data_path "$kaiaulu_data_path/replication/$project" \
      --conf_path "$kaiaulu_path/conf/${project}_replication_analysis.yml" \
      --count --count_save_path "$statistics_path/kaiaulu/replication" \
      --hashes --hash_save_dir_path "$hash_path/kaiaulu/replication/$project" \
      --rank --rank_save_dir_path "$rank_path/kaiaulu/replication/$project" \
      > "$log_path"/statistics_kaiaulu_"$project"_replication.log
  done

# Compare the baseline data across tool configurations.
for project in ${project_list[*]}
  do
    echo "Comparing commit hashes for project $project..."
    python3 "$src_path"/statistics_comparison.py \
      --hashes --hash_dir_path_codeface "$hash_path/codeface/$project" \
      --hash_dir_path_kaiaulu "$hash_path/kaiaulu/prior/$project" \
      --hash_save_dir_path "$hash_path/comparison/prior/$project"

    python3 "$src_path"/statistics_comparison.py \
      --hashes --hash_dir_path_codeface "$hash_path/codeface/$project" \
      --hash_dir_path_kaiaulu "$hash_path/kaiaulu/replication/$project" \
      --hash_save_dir_path "$hash_path/comparison/replication/$project"
  done

echo "Comparing jointly identified files, entities and developers..."
python3 "$src_path"/statistics_comparison.py \
  --rank --k -1 \
  --rank_dir_path_codeface "$rank_path/codeface" \
  --rank_dir_path_kaiaulu "$rank_path/kaiaulu/prior" \
  --rank_save_path "$rank_path/comparison/prior/rankings_comparison_all.csv"

python3 "$src_path"/statistics_comparison.py \
  --rank --k -1 \
  --rank_dir_path_codeface "$rank_path/codeface" \
  --rank_dir_path_kaiaulu "$rank_path/kaiaulu/replication" \
  --rank_save_path "$rank_path/comparison/replication/rankings_comparison_all.csv"

# Report the analysis results.
echo "Creating baseline data similarity plots and tables..."
Rscript "$plot_path"/plot_baseline.R \
  --statistics_path_codeface "$statistics_path/codeface" \
  --statistics_path_kaiaulu_prior "$statistics_path/kaiaulu/prior" \
  --statistics_path_kaiaulu_replication "$statistics_path/kaiaulu/replication" \
  --rank_path_prior "$rank_path/comparison/prior" \
  --rank_path_replication "$rank_path/comparison/replication" \
  --plot_path "$plot_path"
