#!/bin/bash

# Creates a Let's Encrypt certificate to support SSL for an RMap server.
# These keys are useful for development, but must be renewed every 90 days.
# The account used to run the script must have sudo privileges.

################################################################################
# Initialization

source install_common.sh

# Read user configuration settings
source configuration.sh

print_bold_white "Creating certificate with Let's Encrypt:"

ensure_installed epel-release
ensure_installed certbot

################################################################################

# TODO - Ensure that Tomcat is running

# Certbot places files in the root folder of a web site and tries to read them
# at the specified domain.  Our root RMap site does not play nice with this
# approach, so we temporarily replace it with an empty folder (or create one
# if there was no ROOT folder).
ROOT=$TOMCAT_PATH/webapps/ROOT
MOVED=$TOMCAT_PATH/webapps/MOVED
if [[ -d $ROOT ]]; then
    mv $ROOT $MOVED
    WAS_MOVED=true
fi
mkdir $ROOT

# Generate a certificate via the Tomcat server
print_green "Generating certificate..."
certbot certonly --webroot -w $ROOT -d $DOMAIN_NAME \
    || abort "Failed to generate certificate"

# Clean up the ROOT folder
rm -rf $ROOT
if [[ $WAS_MOVED == "true" ]]; then
    mv $MOVED $ROOT
fi

# Convert certificate to PKCS12 format (needed to import into keystore)
print_green "Converting certificate..."
LE_PATH=/etc/letsencrypt/live/$DOMAIN_NAME
openssl pkcs12 -export \
    -in      $LE_PATH/fullchain.pem \
    -inkey   $LE_PATH/privkey.pem \
    -out     $CERTIFICATE_PATH \
    -name    $KEY_NAME \
    -passout pass:$KEY_PASSWORD \
        || abort "Failed to convert certificate"

print_bold_white "Done creating certificate!"
print_white "" # A blank line

