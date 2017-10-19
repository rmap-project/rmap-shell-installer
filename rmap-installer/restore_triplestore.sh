#!/bin/bash

# Uploads a snapshot of triplestore contents to the GraphDB triplestore.
# The account used to run the script must have sudo privileges.

source install_common.sh

# Read user configuration settings
source configuration.sh

confirm_sudo

print_bold_white "Uploading Snapshot to GraphDB Triplestore:"

################################################################################

# Validate arguments
if [[ $# != 1 ]]; then
    print_yellow "Usage: restore_triplestore.sh snapshotfile.nq"
    abort "Missing snapshot file name."
fi

# Validate snapshot file
FILE_NAME=$1
INPUT_FILE=$GRAPHDB_BACKUP_PATH/$FILE_NAME
if [[ ! -e $INPUT_FILE ]]; then
    abort "Could not find snapshot file $INPUT_FILE"
fi

# Link to snapshot file from folder from which GraphDB can upload
ensure_folder "/home/$USERID" "graphdb-import"
SERVER_FILE="/home/$USERID/graphdb-import/$FILE_NAME"
if [[ -e $SERVER_FILE ]]; then
    rm $SERVER_FILE &>> $LOGFILE \
        || abort "Could not remove previous upload file link"
fi
ln -s $INPUT_FILE /home/$USERID/graphdb-import &>> $LOGFILE \
    || abort "Could not create upload file link"

# Clear the current contents of the repository.
# TODO - Offer warning and/or ask user if it's OK to continue before deleting?
print_green "Deleting existing statements..."
curl -X DELETE \
    -u $GRAPHDB_USER:$GRAPHDB_PASSWORD \
    -H 'Accept: application/json' \
    $GRAPHDB_URL/repositories/$GRAPHDB_DBNAME/statements \
    &>> $LOGFILE \
       || abort "Could not delete all statements from GraphDB repository '$GRAPHDB_DBNAME'"

# Upload the snapshot to the repository
print_green "Uploading new statements..."
RESTAPI=$GRAPHDB_URL/rest/data/import/server
curl -X POST \
    -u $GRAPHDB_USER:$GRAPHDB_PASSWORD \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json' \
    &>> $LOGFILE \
       || abort "Could not upload statements to GraphDB repository '$GRAPHDB_DBNAME'"

print_bold_white "The snapshot has been queued for uploading to GraphDB!"
