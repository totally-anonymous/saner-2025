#!/bin/sh
# Copyright Roger Meier <roger@bufferoverflow.ch>
# Copyright Claus Hunsen <hunsen@fim.uni-passau.de>
# SPDX-License-Identifier:	Apache-2.0 BSD-2-Clause GPL-2.0+ MIT WTFPL

echo "Providing codeface database"

sudo mysql -e "CREATE DATABASE codeface;" -uroot
sudo mysql -e "CREATE DATABASE codeface_testing;" -uroot

# Use MySQL native password authentication explicitly because the node 
# mysql package does not support the default SHA2 password 
# authentication provided by MySQL 8
sudo mysql -e "CREATE USER 'codeface'@'localhost' IDENTIFIED WITH mysql_native_password BY 'codeface';" -uroot
sudo mysql -e "GRANT ALL PRIVILEGES ON * . * TO 'codeface'@'localhost';" -uroot
sudo mysql -e "FLUSH PRIVILEGES;" -uroot

# Allow data import from local text file on client host
sudo mysql -e "SET PERSIST local_infile=1;" -uroot

DATAMODEL="datamodel/codeface_schema.sql"
mysql -ucodeface -pcodeface < ${DATAMODEL}
cat ${DATAMODEL} | sed -e 's/codeface/codeface_testing/g' | mysql -ucodeface -pcodeface
