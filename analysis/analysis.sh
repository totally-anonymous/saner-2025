#!/bin/bash

# Prerequisite: Download the source git repositories.
bash 01_git_repos.sh

# Analyse the subjects projects with Codeface.
bash 02_codeface_analysis.sh 16

# Analyse the subject projects with Kaiaulu.
bash 03_kaiaulu_analysis.sh

# Compare baseline data.
bash 04_data_preparation.sh
bash 05_baseline_comparison.sh

# Compare derived developer networks.
bash 06_network_comparison.sh
