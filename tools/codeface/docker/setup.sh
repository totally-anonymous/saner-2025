#! /bin/bash

# Make sure to execute scripts from the intended path
cd /home/saner/tools/codeface

# Install required dependencies
integration-scripts/install_repositories.sh
integration-scripts/install_common.sh
integration-scripts/install_codeface_R.sh
integration-scripts/install_codeface_node.sh
integration-scripts/install_codeface_python.sh
integration-scripts/install_cppstats.sh

# Start the MySQL service
sudo service mysql start

# Allow database connections via the MySQL socket
# for all users
chmod 755 /var/run/mysqld

# Set up Codeface and Codeface test databases
integration-scripts/setup_database.sh
