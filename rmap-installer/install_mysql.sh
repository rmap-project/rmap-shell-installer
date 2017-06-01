#!/bin/bash

# This script installs a MySql server in support of an RMap server.
# The account used to run the script must have sudo privileges.

source install_common.sh

confirm_sudo

ensure_root_folder

ensure_service_stopped mariadb

# Initial root password
# TODO - This needs to come from somewhere
rootpass=""

# Perform a query without printing any text.
quiet_query()
{
    mysql -u root --password=$rootpass -se "$1" &>> $LOGFILE
}

# Perform a query and print its reseults, suitable for assigning to a variable.
value_query()
{
    echo `mysql -u root --password=$rootpass -se "$1" 2>> $LOGFILE`
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

# If databse "rmap" exists, this is an upgrade and no further work is needed.
val=$(value_query "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = 'rmap';")
if [[ $val == 'rmap' ]]; then
    print_white "MySQL upgrade is complete!"
    print_white "" # Blank line
    exit
fi

################################################################################
# Secure the installation.
# These commands are derived from /usr/bin/mysql_secure_installation.
# They seem to work without complaint even if they were run before
# (i.e. the things being deleted are no longer there).

# Set the root password (initially blank)
print_green "Setting root password..."
quiet_query "UPDATE mysql.user SET Password=PASSWORD('rmap') WHERE User='root';" \
    || abort "Could not set root password"
# Note that with access established, the old password is OK for rest of script.

# Delete the temporary user
print_green "Deleting temporary user..."
quiet_query "DELETE FROM mysql.user WHERE User='';" \
    || abort "Could not delete temporary user"

# Disble remote root login
# Might this be needed for RMap?
print_green "Disabling remote login..."
quiet_query "DELETE FROM mysql.user \
    WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" \
        || abort "Could not disable remote root login"

# Remove test database
print_green "Removing test database..."
quiet_query "DROP DATABASE IF EXISTS test;" \
    || abort "Could not drop test database"
quiet_query "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'" \
    || abort "Could not delete test database"

################################################################################
# Create initial database and user

print_green "Creating 'rmap' database..."
quiet_query "CREATE DATABASE rmap" \
    || abort "Could not create database 'rmap'"

print_green "Allowing access for user 'rmap'..."
quiet_query "GRANT ALL PRIVILEGES ON rmap.* TO 'rmap'@'localhost' \
    IDENTIFIED BY 'rmap';" \
        || abort "Could not grant access to user 'rmap'"
# TODO - Allow access from another IP address?

print_green "Creating initial tables..."
cat createTables.sql | mysql -u root --password=$rootpass \
    || abort "Could not create database tables"

print_white "MySQL installation is complete!"
print_white "" # Blank line

