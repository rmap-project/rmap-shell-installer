#!/bin/bash

# This script installs a Tomcat server in support of an RMap server.
# The account used to run the script must have sudo privileges.

# install_common.sh and other initialization is performed in install_java.sh
source install_java.sh

ensure_service_stopped tomcat


################################################################################
# Tomcat files

ensure_sub_folder $TOMCAT_DIR "Tomcat"

# TODO - Do we need to save and restore any folders, or just delete old version?
if [[ -d $TOMCAT_PATH ]]; then
    remove $TOMCAT_PATH
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


################################################################################
# Set up firewall

# Make sure firewall is enabled and started.
# Permanently open ports for HTTP and HTTPS.
# Forward default HTTP and HTTPS ports to Tomcat's ports.
print_green "Setting up Firewall..."
systemctl enable firewalld &>> $LOGFILE \
    || abort "Could not enable firewall"
systemctl start firewalld &>> $LOGFILE \
    || abort "Could not start firewall"
firewall-cmd --zone=public --permanent --add-service=http &>> $LOGFILE \
    || abort "Could not open firewall for http"
firewall-cmd --zone=public --permanent --add-service=https &>> $LOGFILE \
    || abort "Could not open firewall for https"
firewall-cmd --zone=public --permanent \
    --add-forward-port=port=80:proto=tcp:toport=8080 &>> $LOGFILE \
    || abort "Could not forward port 80 to 8080"
firewall-cmd --zone=public --permanent --add-port=8080/tcp &>> $LOGFILE \
    || abort "Could not open port 8080"
firewall-cmd --zone=public --permanent \
    --add-forward-port=port=443:proto=tcp:toport=8443 &>> $LOGFILE \
    || abort "Could not forward port 443 to 8443"
firewall-cmd --zone=public --permanent --add-port=8443/tcp &>> $LOGFILE \
    || abort "Could not open port 8443"
firewall-cmd --reload &>> $LOGFILE \
    || abort "Could not reload firewall settings"


################################################################################
# Tomcat as a Service

# Create and start a service for Tomcat
print_green "Setting up Tomcat service..."
sed "s,USERID,$USERID,; s,JAVAHOME,$JAVA_PATH,; s,TOMCATHOME,$TOMCAT_PATH,; s,NOIDHOME,NOID_PATH," \
    < tomcat.service > /etc/systemd/system/tomcat.service 2>> $LOGFILE \
    || abort "Could not configure Tomcat service"
systemctl daemon-reload &>> $LOGFILE \
    || abort "Could not refresh services list"
systemctl enable tomcat &>> $LOGFILE \
    || abort "Could not enable Tomcat service"
systemctl start tomcat &>> $LOGFILE \
    || abort "Could not start Tomcat server"

# Wait for GraphDB to become responsive
print_yellow_noeol "Starting Tomcat (this can take several seconds)"
IPADDR=`hostname -I | tr -d '[:space:]'` 2>> $LOGFILE \
    || abort "Could not find IP address"
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

