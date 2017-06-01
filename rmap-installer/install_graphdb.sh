#!/bin/bash

# Installs a stand-alone GraphDB server in support of an RMap server.
# The account used to run the script must have sudo privileges.

################################################################################
# Initialization

# install_common.sh and other initialization is performed in install_java.sh
source install_java.sh

ensure_installed unzip

ensure_service_stopped graphdb


################################################################################
# GraphDB files

# If the graphdb folder already exists, move it aside.
# Remember this is now an upgrade so data will be copied back after install.
if [[ -d $GRAPHDB_PATH ]]; then
    print_green "Backing up graphdb data..."
    IS_UPGRADE=true
    BACKUP_PATH=$PARENT_DIR/$GRAPHDB_DIR.back
    if [[ -d $BACKUP_PATH ]]; then
        remove $BACKUP_PATH
    fi
    mv $GRAPHDB_PATH $BACKUP_PATH &>> $LOGFILE \
        || abort "Could not rename GraphDB folder"
fi

# Download GraphDB distribution file
if [[ -f $GRAPHDB_ZIP ]]; then
    remove $GRAPHDB_ZIP
fi
print_green "Downloading graphdb..."
wget --no-verbose $GRAPHDB_URI &>> $LOGFILE \
    || abort "Could not download GraphDB"

# Unzip GraphDB distribution file and rename
print_green "Unzipping graphdb..."
unzip -q $GRAPHDB_ZIP -d $PARENT_DIR &>> $LOGFILE \
    || abort "Could not unzip GraphDB"
remove $GRAPHDB_ZIP

# If update install, move saved folders back
if [[ -n $IS_UPGRADE ]]; then
    print_green "Restoring graphdb data..."
    if [[ -f $BACKUP_PATH/data ]]; then
        cp -r $BACKUP_PATH/data $GRAPHDB_PATH &>> $LOGFILE \
            || abort "Could not restore GraphDB data"
    fi
    if [[ -f $BACKUP_PATH/logs ]]; then
        cp -r $BACKUP_PATH/logs $GRAPHDB_PATH &>> $LOGFILE \
            || abort "Could not restore GraphDB logs"
    fi
    if [[ -f $BACKUP_PATH/work ]]; then
        cp -r $BACKUP_PATH/work $GRAPHDB_PATH &>> $LOGFILE \
            || abort "Could not restore GraphDB work"
    fi
fi

# Replace conf/graphdb.properties file to set data location
print_green "Configuring GraphDB..."
cp graphdb.properties $GRAPHDB_PATH/conf &>> $LOGFILE \
    || abort "Could not install config file"

# The whole folder tree must have the correct ownership
set_owner_and_group $GRAPHDB_PATH


################################################################################
# Set up firewall

# Make sure firewall is enabled and started.  Permanently open port 7200.
if [[ -z $IS_UPGRADE ]]; then
    print_green "Setting up Firewall..."
    systemctl enable firewalld &>> $LOGFILE \
        || abort "Could not enable firewall"
    systemctl start firewalld &>> $LOGFILE \
        || abort "Could not start firewall"
    if [[ `firewall-cmd --list-ports | grep 7200 | wc -l` == 0 ]]; then
        firewall-cmd --zone=public --permanent --add-port=7200/tcp &>> $LOGFILE \
            || abort "Could not open port 7200"
    fi
    firewall-cmd --reload &>> $LOGFILE \
        || abort "Could not reload firewall settings"
fi


################################################################################
# GraphDB as a Service

# Create and start a service for GraphDB
print_green "Setting up GraphDB service..."
sed "s,USERID,$USERID,; s,JAVAHOME,$JAVA_PATH,; s,GRAPHDB,$GRAPHDB_PATH," \
    < graphdb.service > /etc/systemd/system/graphdb.service 2>> $LOGFILE \
    || abort "Could not configure GraphDB service"
systemctl daemon-reload &>> $LOGFILE \
    || abort "Could not refresh services list"
systemctl enable graphdb &>> $LOGFILE \
    || abort "Could not enable GraphDB services"
systemctl start graphdb &>> $LOGFILE \
    || abort "Could not start GraphDB server"

# Find this computer's IP address, build REST API address.
IPADDR=`hostname -I | tr -d '[:space:]'` \
    || abort "Could not find IP address"
RESTAPI=http://$IPADDR:7200/rest

# Wait for GraphDB to become responsive
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


################################################################################
# Initial server configuration

# If we are upgrading, do not initialize the repo, user or security
if [[ -z $IS_UPGRADE ]]; then
    # Create configured rmap repo via web API
    print_green "Creating 'rmap' repository..."
    curl -X POST \
        $RESTAPI/repositories \
        -H 'Content-Type: multipart/form-data' \
        -F "config=@rmap-config.ttl" \
        &>> $LOGFILE \
            || abort "Could not create GraphDB repository 'rmap'"

    # Create rmap user via web API
    # TODO - Move JSON to file so we can catch stdout/stderr in log file?
    print_green "Creating user 'rmap'..."
    curl -X POST \
        $RESTAPI/security/user \
        -H 'Content-Type: application/json' \
        -H 'Accept: text/plain' \
        -d @- << EOF
        {
            "username": "rmap",
            "password": "rmap",
            "confirmpassword": "rmap",
            "grantedAuthorities": ["ROLE_USER", "ROLE_REPO_ADMIN"]
        }
EOF
    [[ $? ]] \
        || abort "Could not create GraphDB user 'rmap'"
    print_yellow "   The initial password for GraphDB user 'rmap' is 'rmap'."
    print_yellow "   Use the GraphDB Workbench (http://$IPADDR:7200) to change the password"

    # Turn security on via web API
    print_green "Adjusting security settings..."
    curl -X POST \
        $RESTAPI/security \
        -H 'Content-Type: application/json' \
        -H 'Accept: */*' \
        -d 'true' \
        &>> $LOGFILE \
            || abort "Could not turn on GraphDB security"

    # Turning "Free Access" off causes an HTTP 400 error.
    #curl -X POST \
    #    $RESTAPI/security/freeaccess \
    #    -H 'Content-Type: application/json' \
    #    -H 'Accept: */*' \
    #    -d { "authorities": ["string"], "enabled": false } \
    #    &>> $LOGFILE
fi

if [[ -z $IS_UPGRADE ]]; then
    print_white "Done installing GraphDB!"
else
    print_white "Done upgrading GraphDB!"
fi
echo # A blank line

