#!/bin/bash

# Installs a Tomcat server in support of an RMap server.
# The account used to run the script must have sudo privileges.

# Only include this file once
[[ -n "$RMAP_TOMCAT_INCLUDED" ]] && return
RMAP_TOMCAT_INCLUDED=true

# install_common.sh and other initialization is performed in install_java.sh
source install_java.sh

# Read user configuration settings
source configuration.sh

print_bold_white "Installing Tomcat:"

ensure_service_stopped tomcat

################################################################################
# Determine install type

# There is either no previous installation (NEW),
# or the installed version is the current version (REFRESH)
# or there is a previous version that must be replaced (UPGRADE).
# Assume there can only be one previous version.
installed_version=`find /rmap -maxdepth 1 -name apache-tomcat-* -not -name *.back`
if [[ $installed_version == "" ]]; then
    print_green "Will perform initial Tomcat installation."
    INSTALL_TYPE=NEW
elif [[ $installed_version == $TOMCAT_PATH ]]; then
    print_green "Will refresh the Tomcat installation."
    INSTALL_TYPE=REFRESH
else
    print_green "Will upgrade the Tomcat installation."
    INSTALL_TYPE=UPGRADE
fi

################################################################################
# Tomcat files

# For an upgrade, move existing folder aside so data can be copied back later.
if [[ $INSTALL_TYPE == "UPGRADE" ]]; then
    print_green "Backing up Tomcat data..."
    BACKUP_PATH=$installed_version.back
    if [[ -d $BACKUP_PATH ]]; then
        remove $BACKUP_PATH
    fi
    mv $installed_version $BACKUP_PATH &>> $LOGFILE \
        || abort "Could not rename Tomcat folder"
fi

# If this is not a refresh, get and install the new version
if [[ $INSTALL_TYPE != "REFRESH" ]]; then
    # Download and unzip Tomcat content
    print_green "Downloading Tomcat..."
    if [[ -f $TOMCAT_ZIP ]]; then
        remove $TOMCAT_ZIP
    fi
    wget --no-verbose $TOMCAT_URI &>> $LOGFILE \
        || abort "Could not download Tomcat"

    print_green "Installing Tomcat..."
    tar -xf $TOMCAT_ZIP -C $PARENT_DIR &>> $LOGFILE \
        || abort "Could not unzip Tomcat"
    # Move Tomcat from root URL to /tomcat.  RMap app will be installed at root.
    mv $TOMCAT_PATH/webapps/ROOT $TOMCAT_PATH/webapps/tomcat
    remove $TOMCAT_ZIP
    set_owner_and_group $TOMCAT_PATH
fi

# Configure Tomcat
print_green "Configuring Tomcat..."
sed "s,KEYSTORE_FILE,$KEYSTORE_FILE,; s,KEYSTORE_PASSWORD,$KEYSTORE_PASSWORD," \
    < server.xml > $TOMCAT_PATH/conf/server.xml 2>> $LOGFILE \
        || abort "Could not install config file"
cp catalina.properties $TOMCAT_PATH/conf &>> $LOGFILE \
    || abort "Could not install properties file"

# If update install, restore some saved content
if [[ $INSTALL_TYPE == "UPGRADE" ]]; then
    print_green "Restoring Tomcat data..."
    # SSL keystore
    OLD_KEYSTORE_PATH=$BACKUP_PATH/conf/$KEYSTORE_FILE
    if [[ -f $OLD_KEYSTORE_PATH ]]; then
        cp -r $OLD_KEYSTORE_PATH $KEYSTORE_PATH &>> $LOGFILE \
            || abort "Could not restore Tomcat SSL keystore"
    fi
fi


################################################################################
# Set up firewall

# For new intalls, initialize some firewall functionality:
#   Make sure iptables is enabled and started.
#   Forward default HTTP and HTTPS ports to Tomcat's ports.
#   Save settings for use when iptables restarts.
# Starting the service can add some unwanted rules to the tables,
# so flush all rules after starting.
#   WARNING: This may disrupt systems with existing rules!

if [[ $INSTALL_TYPE == "NEW" ]]; then
    ensure_installed iptables-services
    print_green "Setting up Firewall..."
    systemctl enable iptables &>> $LOGFILE \
        || abort "Could not enable iptables"
    systemctl start iptables &>> $LOGFILE \
        || abort "Could not start iptables"
    iptables -F \
        || abort "Could not flush iptables rules"
    iptables -t nat -I PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080 \
        &>> $LOGFILE \
        || abort "Could not forward port 80 to 8080"
    iptables -t nat -I OUTPUT -p tcp -o lo --dport 80 -j REDIRECT --to-ports 8080 \
        &>> $LOGFILE \
        || abort "Could not forward port 80 to 8080"
    iptables -t nat -I PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443 \
        &>> $LOGFILE \
        || abort "Could not forward port 443 to 8443"
    iptables -t nat -I OUTPUT -p tcp -o lo --dport 443 -j REDIRECT --to-ports 8443 \
        &>> $LOGFILE \
        || abort "Could not forward port 443 to 8443"
    service iptables save &>> $LOGFILE \
        || "Could not save iptables settings"
fi


################################################################################
# Tomcat as a Service

# Create and start a service for Tomcat
if [[ $INSTALL_TYPE != "REFRESH" ]]; then
    print_green "Setting up Tomcat service..."
    sed "s,USERID,$USERID,; s,JAVAHOME,$JAVA_PATH,; s,TOMCATHOME,$TOMCAT_PATH,; s,NOIDHOME,$NOID_PATH," \
        < tomcat.service > /etc/systemd/system/tomcat.service 2>> $LOGFILE \
        || abort "Could not configure Tomcat service"
    systemctl daemon-reload &>> $LOGFILE \
        || abort "Could not refresh services list"
    systemctl enable tomcat &>> $LOGFILE \
        || abort "Could not enable Tomcat service"
fi

print_green "Starting Tomcat service..."
systemctl start tomcat &>> $LOGFILE \
    || abort "Could not start Tomcat server"

# Wait for GraphDB to become responsive
print_yellow_noeol "Starting Tomcat (this can take several seconds)"
status=1
while [[ $status != 0 ]]
do
    print_yellow_noeol "."
    sleep 1
    curl -m 1 http://$IPADDR:8080 > /dev/null 2>> $LOGFILE
    status=$?
done
print_white ""


################################################################################
# Configure server

# TODO - Do we want to configure an admin user here?

if [[ $INSTALL_TYPE == "NEW" ]]; then
    print_bold_white "Done installing Tomcat!"
elif [[ $INSTALL_TYPE == "REFRESH" ]]; then
    print_bold_white "Done refreshing Tomcat!"
else
    print_bold_white "Done upgrading Tomcat!"
fi
print_white "" # A blank line

