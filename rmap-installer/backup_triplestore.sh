#!/bin/bash

# Makes a copy of the current contents of the GraphDB triplestore.
# The account used to run the script must have sudo privileges.

source install_common.sh

# Read user configuration settings
source configuration.sh

confirm_sudo

print_bold_white "Creating snapshot of GraphDB triplestore:"

################################################################################

# TODO - Allow backup folder name to be a configurable?  Configurable location?
BACKUP_FOLDER=backups
ensure_folder "$GRAPHDB_PATH" "$BACKUP_FOLDER"

# TODO - Allow backup file name to be configurable?
FILE_NAME="statements.$(date +%F-%R).nq"
OUTPUT_FILE=$GRAPHDB_PATH/$BACKUP_FOLDER/$FILE_NAME

print_green "Downloading snapshot of GraphDB statements..."
curl -X GET \
    -u $GRAPHDB_USER:$GRAPHDB_PASSWORD \
    -H 'Accept: application/n-quads' \
    -o $OUTPUT_FILE \
    http://$GRAPHDB_DOMAIN_NAME:7200/repositories/$GRAPHDB_DBNAME/statements \
    &>> $LOGFILE \
        || abort "Could not download statements from GraphDB repository '$GRAPHDB_DBNAME'"

set_owner_and_group $OUTPUT_FILE

print_bold_white "Done creating snapshot!"

