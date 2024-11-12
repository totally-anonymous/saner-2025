#! /bin/sh

project=$1

echo "Start:" `date -u`
start=`date +%s`

printf 'Analysing %s with Kaiaulu...\n' "$project"

eval "$(/home/saner/anaconda3/bin/conda shell.bash hook)"
conda activate kaiaulu

# Start analysis for the prior configuration
mkdir -p /home/saner/data/kaiaulu/rawdata/gitlog/prior/"${project}"/entities

# Git log analysis
Rscript /home/saner/tools/kaiaulu/exec/git.R tabulate \
  /home/saner/tools/kaiaulu/tools.yml \
  /home/saner/tools/kaiaulu/conf/"${project}"_prior_analysis.yml \
  /home/saner/tools/kaiaulu/conf/"${project}"_prior_cli.yml \
  /home/saner/data/kaiaulu/rawdata/gitlog/prior/"${project}"/gitlog_filtered.csv

# Git blame (entity) analysis
Rscript /home/saner/tools/kaiaulu/exec/git.R entity parallel \
  /home/saner/tools/kaiaulu/tools.yml \
  /home/saner/tools/kaiaulu/conf/"${project}"_prior_analysis.yml \
  /home/saner/tools/kaiaulu/conf/"${project}"_prior_cli.yml \
  /home/saner/data/kaiaulu/rawdata/gitlog/prior/"${project}"/gitlog_filtered.csv \
  /home/saner/data/kaiaulu/rawdata/gitlog/prior/"${project}"/entities

# Start analysis for the replication configuration
mkdir -p /home/saner/data/kaiaulu/rawdata/gitlog/replication/"${project}"/entities

# Git log analysis
Rscript /home/saner/tools/kaiaulu/exec/git.R tabulate \
  /home/saner/tools/kaiaulu/tools.yml \
  /home/saner/tools/kaiaulu/conf/"${project}"_replication_analysis.yml \
  /home/saner/tools/kaiaulu/conf/"${project}"_replication_commits_cli.yml \
  /home/saner/data/kaiaulu/rawdata/gitlog/replication/"${project}"/gitlog_complete.csv
Rscript /home/saner/tools/kaiaulu/exec/git.R tabulate \
  /home/saner/tools/kaiaulu/tools.yml \
  /home/saner/tools/kaiaulu/conf/"${project}"_replication_analysis.yml \
  /home/saner/tools/kaiaulu/conf/"${project}"_replication_cli.yml \
  /home/saner/data/kaiaulu/rawdata/gitlog/replication/"${project}"/gitlog_filtered.csv

# Git blame (entity) analysis
Rscript /home/saner/tools/kaiaulu/exec/git.R entity parallel \
  /home/saner/tools/kaiaulu/tools.yml \
  /home/saner/tools/kaiaulu/conf/"${project}"_replication_analysis.yml \
  /home/saner/tools/kaiaulu/conf/"${project}"_replication_cli.yml \
  /home/saner/data/kaiaulu/rawdata/gitlog/replication/"${project}"/gitlog_filtered.csv \
  /home/saner/data/kaiaulu/rawdata/gitlog/replication/"${project}"/entities

echo "End:" `date -u`
end=`date +%s`
d=$(($end-$start))
printf 'Time elapsed: %dd:%dh:%dm:%ds (%ds)\n' $((d/86400)) \
        $((d%86400/3600)) $((d%3600/60)) $((d%60)) $d

