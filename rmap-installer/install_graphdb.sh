#!/bin/bash

# Installs a stand-alone GraphDB server in support of an RMap server.
# The account used to run the script must have sudo privileges.

# Only include this file once
[[ -n "$RMAP_GRAPHDB_INCLUDED" ]] && return
RMAP_GRAPHDB_INCLUDED=true

################################################################################
# Initialization

# install_common.sh and other initialization is performed in install_java.sh
source install_java.sh

# Read user configuration settings
source configuration.sh

print_bold_white "Installing GraphDB:"

ensure_installed unzip

ensure_service_stopped graphdb

################################################################################
# GraphDB files

# Determine install type:
# There is either no previous installation (NEW),
# or there is a previous version that must be replaced (UPGRADE),
# or the current versios is already installed (NONE).
# Assume there can only be one previous version.
installed_version=`find /rmap -maxdepth 1 -name graphdb-free-* -not -name *.back`
if [[ $installed_version == "" ]]; then
    print_green "Will perform initial GraphDB installation."
    INSTALL_TYPE=NEW
elif [[ $installed_version != $GRAPHDB_PATH ]]; then
    print_green "Will upgrade the GraphDB installation."
    INSTALL_TYPE=UPGRADE
else
    print_green "GraphDB installation is up to date."
    INSTALL_TYPE=NONE
fi

if [[ $INSTALL_TYPE != "NONE" ]]; then
    # For upgrades, save the current GraphDB folder as a backup
    if [[ $INSTALL_TYPE == "UPGRADE" ]]; then
        print_green "Backing up graphdb data..."
        BACKUP_PATH=$installed_version.back
        if [[ -d $BACKUP_PATH ]]; then
            remove $BACKUP_PATH
        fi
        mv $installed_version $BACKUP_PATH &>> $LOGFILE \
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
    if [[ $INSTALL_TYPE == "UPGRADE" ]]; then
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

################################################################################
# Initial server configuration

# If we are upgrading, do not initialize the repo, user or security
if [[ -z $IS_UPGRADE ]]; then
    # Create configured rmap repo via web API
    print_green "Creating initial repository..."
    curl -X POST \
        -u admin:root \
        -H 'Content-Type: multipart/form-data' \
        -F "config=@rmap-config.ttl" \
        $RESTAPI/repositories \
        &>> $LOGFILE \
            || abort "Could not create initial GraphDB repository '$GRAPHDB_DBNAME'"

    # Create rmap user via web API
    print_green "Creating user 'rmap'..."
    JSON="
        {
            \"username\": \"$GRAPHDB_USER\",
            \"password\": \"$GRAPHDB_PASSWORD\",
            \"confirmpassword\": \"$GRAPHDB_PASSWORD\",
            \"grantedAuthorities\": [\"ROLE_USER\", \"ROLE_REPO_ADMIN\"]
        }
    "
    curl -X POST \
        -u admin:root \
        -H 'Content-Type: application/json' \
        -H 'Accept: text/plain' \
        -d "$JSON" \
        $RESTAPI/security/user \
	&>> $LOGFILE \
            || abort "Could not create GraphDB user '$GRAPHDB_USER'"

    # Turn security on via web API
    print_green "Adjusting security settings..."
    curl -X POST \
        -u admin:root \
        -H 'Content-Type: application/json' \
        -H 'Accept: */*' \
        -d 'true' \
        $RESTAPI/security \
        &>> $LOGFILE \
            || abort "Could not turn on GraphDB security"

    # Turning "Free Access" off causes an HTTP 400 error.
    #curl -X POST \
    #    -u admin:root \
    #    -H 'Content-Type: application/json' \
    #    -H 'Accept: */*' \
    #    -d { "authorities": ["string"], "enabled": false } \
    #    $RESTAPI/security/freeaccess \
    #    &>> $LOGFILE

    # If this is not the system where Tomcat is running, set up the firewall:
    #   Clear out any rules that might mess up our efforts.
    #   Open the GraphDB port.
    #   Save settings for use when iptables restarts.
    # WARNING: This may disrupt systems with existing rules!
    if [[ $GRAPHDB_DOMAIN_NAME != "localhost" && \
    $GRAPHDB_DOMAIN_NAME != $TOMCAT_DOMAIN_NAME ]]; then
        print_green "Configuring Firewall..."
        iptables -F \
            || abort "Could not flush iptables rule chains"
        iptables -X \
            || abort "Could not flush iptables rule chains"
        iptables -t nat -F \
            || abort "Could not flush iptables rule chains"
        iptables -t nat -X \
            || abort "Could not flush iptables rule chains"
        iptables -t nat -A INPUT -p tcp --dport 7200 -j ACCEPT \
            &>> $LOGFILE \
            || abort "Could not open port 3306"
        service iptables save &>> $LOGFILE \
            || "Could not save iptables settings"
    fi

fi

if [[ -z $IS_UPGRADE ]]; then
    print_bold_white "Done installing GraphDB!"
else
    print_bold_white "Done upgrading GraphDB!"
fi
echo # A blank line

