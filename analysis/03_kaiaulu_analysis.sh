#!/bin/bash

source analysis.conf

# Analyse all subject projects with Kaiaulu.
for project in ${project_list[*]}
  do
    bash "$kaiaulu_path"/analysis.sh "${project}"
  done