#!/bin/bash

cores=$1

source analysis.conf

sudo mkdir -p $codeface_data_path

# Analyse all subject projects with Codeface.
for project in ${project_list[*]}
  do
    cd "$codeface_path"
    bash "$codeface_path"/analysis.sh "${project}" "${cores}"
  done
