#!/bin/bash

source analysis.conf

# Clone the git repositories of all subject projects for analysis.
for project in ${project_list[*]}
  do
    cd "$base_path"/data/git-repos
    if [ "$project" == "camel" ]; then
      git clone https://github.com/apache/camel.git
      cd camel
      git checkout c7aa49f8c83b0aca3b62984b6ccfe0a3d3bcee4f
    elif [ "$project" == "django" ]; then
      git clone https://github.com/django/django.git
      cd django
      git checkout d9b91e38361696014bdc98434d6d018eae809519
    elif [ "$project" == "gtk" ]; then
      git clone https://gitlab.gnome.org/GNOME/gtk.git
      cd gtk
      git checkout 9f8e84cb609f2a8090b9ca0b4dc801c4802649ca
    elif [ "$project" == "jailhouse" ]; then
      git clone https://github.com/siemens/jailhouse.git
      cd jailhouse
      git checkout e57d1eff6d55aeed5f977fe4e2acfb6ccbdd7560
    elif [ "$project" == "openssl" ]; then
      git clone https://github.com/openssl/openssl.git
      cd openssl
      git checkout 0f644b96d209443b4566f7e86e3be2568292e75b
    elif [ "$project" == "postgres" ]; then
      git clone https://github.com/postgres/postgres.git
      cd postgres
      git checkout 6f97ef05d62a9c4ed5c53e98ac8a44cf3e0a2780
    elif [ "$project" == "qemu" ]; then
      git clone https://gitlab.com/qemu-project/qemu.git
      cd qemu
      git checkout 34eac35f893664eb8545b98142e23d9954722766
    elif [ "$project" == "rstudio" ]; then
      git clone https://github.com/rstudio/rstudio.git
      cd rstudio
      git checkout a6f3287ef5428516112bcd8bfa78abdb1a2fb3c8
    elif [ "$project" == "spark" ]; then
      git clone https://github.com/apache/spark.git
      cd spark
      git checkout c84ac6f7cf4e4395d0ad02194d5dcc38cb67f174
    elif [ "$project" == "wine" ]; then
      git clone git://source.winehq.org/git/wine.git
      cd wine
      git checkout 866f17c147e4d76b6dd14ad98030918c341cde38
    else
      echo "The specified project was not part of the study. Please clone the repository manually."
    fi
  done