#!/bin/bash

# This script installs a MariaDB server in support of an RMap server.
# The account used to run the script must have sudo privileges.

# Only include this file once
[[ -n "$RMAP_MARIADB_INCLUDED" ]] && return
RMAP_MARIADB_INCLUDED=true

source install_common.sh

# Read user configuration settings
source configuration.sh

print_bold_white "Installing MariaDB:"

confirm_sudo

ensure_root_folder

ensure_service_stopped mariadb

# Perform a MySQL query without printing any text.
quiet_query()
{
    mysql -u root -p$MARIADB_PASSWORD -se "$1" &>> $LOGFILE
}

# Perform a MySQL query and print its reseults, suitable for assigning to a variable.
value_query()
{
    echo `mysql -u root -p$MARIADB_PASSWORD -se "$1" 2>> $LOGFILE`
}

################################################################################
# Installation

# Install MariaDB, if needed
ensure_installed mariadb
ensure_installed mariadb-server

# Start and enable the service
print_green "Setting up MariaDB service..."
systemctl enable mariadb &>> $LOGFILE \
    || abort "Could not enable MariaDB services"
systemctl start mariadb &>> $LOGFILE \
    || abort "Could not start MariaDB server"

# If the root user already has a password, this script was run before.
mysql -u root -p$MARIADB_PASSWORD -se ";" &>> /dev/null
if [[ $? == 0 ]]; then
    print_bold_white "Done upgrading MariaDB!"
    print_white "" # Blank line
else

################################################################################
# First time here - Secure the installation.
# These commands are derived from /usr/bin/mysql_secure_installation.
# They seem to work without complaint even if they were run before
# (i.e. the things being deleted are no longer there).

    # Set the root password
    print_green "Setting root password..."
    mysql -u root -se "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$MARIADB_PASSWORD');" \
        || abort "Could not set root password"

    # Disble remote root login
    # Might this be needed for RMap?
    print_green "Disabling remote login..."
    quiet_query "DELETE FROM mysql.user \
        WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" \
            || abort "Could not disable remote root login"

    # Delete the temporary user
    print_green "Deleting temporary user..."
    quiet_query "DELETE FROM mysql.user WHERE User='';" \
        || abort "Could not delete temporary user"

    # Remove test database
    print_green "Removing test database..."
    quiet_query "DROP DATABASE IF EXISTS test;" \
        || abort "Could not drop test database"
    quiet_query "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'" \
        || abort "Could not delete test database"

################################################################################
# First time here - Create initial database and user privileges

    print_green "Creating initial database..."
    quiet_query "CREATE DATABASE $MARIADB_DBNAME" \
        || abort "Could not create database '$MARIADB_DBNAME'"

    print_green "Creating initial tables..."
    cat createTables.sql | mysql -u root --password=$MARIADB_PASSWORD \
        || abort "Could not create database tables"

    # TODO - Should this be done on each upgrade?
    print_green "Allowing access for user '$MARIADB_USER'..."
    quiet_query "GRANT ALL PRIVILEGES ON $MARIADB_DBNAME.* TO '$MARIADB_USER'@'localhost' \
        IDENTIFIED BY '$MARIADB_PASSWORD';" \
            || abort "Could not grant access to user '$MARIADB_USER'"
    # TODO - Requests coming from '$MARIADB_USER'@'this-system's-IP' should work,
    # but it seems necessary to allow access from all IP addresses:
    quiet_query "GRANT ALL PRIVILEGES ON $MARIADB_DBNAME.* TO '$MARIADB_USER'@'%' \
        IDENTIFIED BY '$MARIADB_PASSWORD';" \
            || abort "Could not grant access to user '$MARIADB_USER'"

    print_bold_white "Done installing MariaDB!"
    print_white "" # Blank line

    # If this is not the system where Tomcat is running, set up the firewall:
    #   Clear out any rules that might mess up our efforts.
    #   Open the MariaDB port.
    #   Save settings for use when iptables restarts.
    # WARNING: This may disrupt systems with existing rules!
    if [[ $MARIADB_DOMAIN_NAME != "localhost" && \
    $MARIADB_DOMAIN_NAME != $TOMCAT_DOMAIN_NAME ]]; then
        print_green "Configuring Firewall..."
        iptables -F \
            || abort "Could not flush iptables rule chains"
        iptables -X \
            || abort "Could not flush iptables rule chains"
        iptables -t nat -F \
            || abort "Could not flush iptables rule chains"
        iptables -t nat -X \
            || abort "Could not flush iptables rule chains"
        iptables -t nat -A INPUT -p tcp --dport 3306 -j ACCEPT \
            &>> $LOGFILE \
            || abort "Could not open port 3306"
        service iptables save &>> $LOGFILE \
            || "Could not save iptables settings"
    fi

fi

