#!/bin/bash

# User-editable settings to control the behavior of the RMap install scripts.

# TODO - Replace these settings with code to process similar assignments
#        in the RMap properties file.

################################################################################

# The system hosting the RMap server must be reachable through a domain name.
# This must be set up before the installation scripts are run.
DOMAIN_NAME=rmap2.trumbore.com

################################################################################

# Information about the keystore file that is used by RMap's Tomcat installation.
# This is used to create and access the keystore file, and can't be changed
# when the installer is run to upgrade the installation.
KEYSTORE_PASSWORD=rmaprmap

################################################################################

# Information about the certificate used to provide SSL access to the servers.
# CERTIFICATE_PATH must be assigned and should point to a secure location.
# This path either points to an existing certificate file or specifies the
# location at which the certificate creation script will generate a file.
CERTIFICATE_PATH=./rmap.pfx
KEY_NAME=tomcat
KEY_PASSWORD=rmaprmap
