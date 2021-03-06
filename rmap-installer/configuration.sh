#!/bin/bash

# User-editable settings to control the behavior of the RMap install scripts.

################################################################################

# The systems hosting the RMap server components must be reachable through a
# domain name.  This must be set up before the installation scripts are run.
# "localhost" is a valid name for the GRAPHDB and MARIADB domains if they
# are running on the same system as the Tomcat component.
TOMCAT_DOMAIN_NAME=[yourdomain]
GRAPHDB_DOMAIN_NAME=localhost
MARIADB_DOMAIN_NAME=localhost

################################################################################

# Information about the keystore file that is used by RMap's Tomcat installation.
# This is used to create and access the keystore file, and can't be changed
# when the installer is run to upgrade the installation.
# The password must be at least six characters long.
KEYSTORE_PASSWORD=rmaprmap

################################################################################

# Information about the certificate used to provide SSL access to the servers.
# CERTIFICATE_PATH must be assigned and should point to a secure location.
# This path either points to an existing certificate file or specifies the
# location at which the certificate creation script will generate a file.
# The password must be at least six characters long.
CERTIFICATE_PATH=./rmap.pfx
KEY_NAME=tomcat
KEY_PASSWORD=rmaprmap

################################################################################

# Information about the initial database and user that are created for MariaDB.
# Run the command 'mysql' to change the user's password.
MARIADB_DBNAME=rmap
MARIADB_USER=rmap
MARIADB_PASSWORD=rmap

################################################################################

# Information about the initial database and user that are created for GraphDB.
# Use port 7200 at the GraphDB Workbench domain to change the user's password. 
GRAPHDB_DBNAME=rmap
GRAPHDB_USER=rmap
GRAPHDB_PASSWORD=rmap

# The heap size to be used by the GraphDB process, as specified for a Java process.
# Examples are 2g or 2048m for 2 Gigabytes.
GRAPHDB_HEAP_SIZE=5g

################################################################################

# Variables to control the backup and restore scripts for GraphDB.

# Local path where backup files are stored.  Will be created if nonexistant.
GRAPHDB_BACKUP_PATH=/rmap/graphdb/backups

# URL for the GraphDB server root, typically http://$GRAPHDB_DOMAIN_NAME:7200.
GRAPHDB_URL=http://$GRAPHDB_DOMAIN_NAME:7200

# MIME type and file extension for creating backup files.
# Common pairings are text/x-nquads and "nq", application/ld+json and "jsonld".
# See http://graphdb.ontotext.com/documentation/6.6/standard/quick-start-guide.html#supported-export-download-formats
GRAPHDB_BACKUP_MIME_TYPE=text/x-nquads
GRAPHDB_BACKUP_FILE_EXT=nq

################################################################################

# Information about the OAuth credentials that will be used to allow new users
# to register themselves with the RMap server.

# The Google OAuth account must authorize https://[yourdomain]/user/googlecallback.
# The Google OAuth account must enable the Google+ API.
GOOGLE_OAUTH_KEY=[yourkey]
GOOGLE_OAUTH_SECRET=[yoursecret]

