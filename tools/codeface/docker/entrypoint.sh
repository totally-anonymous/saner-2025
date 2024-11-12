#! /bin/bash

# Start MySQL service
sudo service mysql start

# Start ID service accessing the database
cd /home/saner/codeface/id_service
bash start_id_service.sh&

# Prepare for user interaction
/bin/bash
