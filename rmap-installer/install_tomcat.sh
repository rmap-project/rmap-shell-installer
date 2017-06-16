#!/bin/bash

# This script installs a Tomcat server in support of an RMap server.
# The account used to run the script must have sudo privileges.

# Only include this file once
[[ -n "$RMAP_TOMCAT_INCLUDED" ]] && return
RMAP_TOMCAT_INCLUDED=true

source install_common.sh

source install_java.sh

ensure_service_stopped tomcat


################################################################################
# Tomcat files

# If the tomcat folder already exists, move it aside.
# Remember this is now an upgrade so data will be copied back after install.
if [[ -d $TOMCAT_PATH ]]; then
    print_green "Backing up Tomcat data..."
    IS_UPGRADE=true
    BACKUP_PATH=$PARENT_DIR/$TOMCAT_DIR.back
    if [[ -d $BACKUP_PATH ]]; then
        remove $BACKUP_PATH
    fi
    mv $TOMCAT_PATH $BACKUP_PATH &>> $LOGFILE \
        || abort "Could not rename Tomcat folder"
fi

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
remove $TOMCAT_ZIP
set_owner_and_group $TOMCAT_PATH

# Configure Tomcat
print_green "Configuring Tomcat..."
cp server.xml $TOMCAT_PATH/conf &>> $LOGFILE \
    || abort "Could not install config file"
cp catalina.properties $TOMCAT_PATH/conf &>> $LOGFILE \
    || abort "Could not install properties file"

# If update install, move saved files back
if [[ -n $IS_UPGRADE ]]; then
    print_green "Restoring Tomcat data..."
    if [[ -f $BACKUP_PATH/conf/localhost-rsa.jks ]]; then
        cp -r $BACKUP_PATH/conf/localhost-rsa.jks $TOMCAT_PATH/conf &>> $LOGFILE \
            || abort "Could not restore Tomcat work"
    fi
fi


################################################################################
# Set up firewall

# Make sure iptables is enabled and started.
# Forward default HTTP and HTTPS ports to Tomcat's ports.
# Save settings for use when iptables restarts.
# Starting the service adds some unwanted rules to the tables,
# so flush all rules after starting.
# WARNING!  This will disrupt systems with existing rules!

if [[ -z $IS_UPGRADE ]]; then
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
if [[ -z $IS_UPGRADE ]]; then
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
# TODO - Do we want to move the Tomcat home page to a different URL?

if [[ -z $IS_UPGRADE ]]; then
    print_white "Done installing Tomcat!"
else
    print_white "Done upgrading Tomcat!"
fi
echo # A blank line

