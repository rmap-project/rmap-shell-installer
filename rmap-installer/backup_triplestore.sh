#!/bin/bash

# Makes a copy of the current contents of the GraphDB triplestore.
# The account used to run the script must have sudo privileges.

source install_common.sh

# Read user configuration settings
source configuration.sh

confirm_sudo

print_bold_white "Creating snapshot of GraphDB triplestore:"

################################################################################

# Ensure the backup folder and path exist and determine the file name.
mkdir -p $GRAPHDB_BACKUP_PATH
FILE_NAME=$GRAPHDB_DBNAME".$(date +%F-%R)."$GRAPHDB_BACKUP_FILE_EXT
OUTPUT_FILE=$GRAPHDB_BACKUP_PATH/$FILE_NAME

print_green "Downloading snapshot of GraphDB statements..."
curl -X GET \
    -u $GRAPHDB_USER:$GRAPHDB_PASSWORD \
    -H "Accept: $GRAPHDB_BACKUP_MIME_TYPE" \
    -o $OUTPUT_FILE \
    $GRAPHDB_URL/repositories/$GRAPHDB_DBNAME/statements \
    &>> $LOGFILE \
        || abort "Could not download statements from GraphDB repository '$GRAPHDB_DBNAME'"

set_owner_and_group $OUTPUT_FILE

print_bold_white "Done creating snapshot $FILE_NAME"

