#!/bin/bash

# Uploads a snapshot of triplestore contents to the GraphDB triplestore.
# The account used to run the script must have sudo privileges.
# GraphDB is stopped and the upload is performed offline, which makes it
# faster due to all re-indexing being performed at the end.

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

# The server must be offline when the upload is performed
ensure_service_stopped graphdb

# Upload the snapshot to the repository
print_green "Uploading new statements..."
# The LoadRDF command installed with GraphDB calls Java to run the uploader,
# but doesn't allow a heap size to be specified.  The command is reproduced here
# in a way that lets us control the heap size.
HEAP="-Xms$GRAPHDB_HEAP_SIZE -Xmx$GRAPHDB_HEAP_SIZE"
$JAVA_PATH/bin/java $HEAP -cp "$GRAPHDB_PATH/lib/*" \
    -Dgraphdb.dist="$GRAPHDB_PATH" \
    -Djdk.xml.entityExpansionLimit=0 \
    com.ontotext.graphdb.loadrdf.LoadRDF \
    -m serial -i $GRAPHDB_DBNAME -f $INPUT_FILE \
    | tee -a $LOGFILE \
   || abort "Could not upload statements to GraphDB repository '$GRAPHDB_DBNAME'"

#export JAVA_HOME=$JAVA_PATH
#$GRAPHDB_PATH/bin/loadrdf -m serial -i $GRAPHDB_DBNAME -f $INPUT_FILE | tee -a $LOGFILE \
#   || abort "Could not upload statements to GraphDB repository '$GRAPHDB_DBNAME'"

# Uploaded data is initially owned by root - set to our username
set_owner_and_group $GRAPHDB_PATH/data/repositories/$GRAPHDB_DBNAME

print_green "Restarting GraphDB service..."
systemctl start graphdb &>> $LOGFILE \
    || abort "Could not start GraphDB server"

# Wait for GraphDB to become responsive
RESTAPI=http://$IPADDR:7200/rest
print_yellow_noeol "Starting GraphDB (this can take several minutes)"
status=0
while [[ $status != 'false' && $status != 'true' ]]
do
    print_yellow_noeol "."
    sleep 5
    status=$( curl -X GET -m 1 -H 'Accept: application/json' \
        $RESTAPI/security 2>> $LOGFILE )
done
print_white ""

print_bold_white "The snapshot has been uploaded to GraphDB!"
