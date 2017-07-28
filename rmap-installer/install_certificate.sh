#!/bin/bash

# Imports a certificate into the keystore to support SSL for this server.
# The account used to run the script must have sudo privileges.

################################################################################
# Initialization

# install_common.sh and other initialization is performed in install_tomcat.sh
source install_tomcat.sh

# Read user configuration settings
source configuration.sh

print_bold_white "Installing SSL certificate:"

################################################################################

# If the keystore file exists and contains the certificate, we're done.
if [[ -f $KEYSTORE_PATH ]]; then
    $JAVA_PATH/bin/keytool \
        -list \
        -alias     $KEY_NAME \
        -keystore  $KEYSTORE_PATH \
        -storepass $KEYSTORE_PASSWORD \
        &>> $LOGFILE \
            && {
                print_yellow "   Certificate already exists in keystore!"
                exit
            }
fi

# Add certificate to keystore, possibly creating keystore file
print_green "Importing certificate into keystore..."
$JAVA_PATH/bin/keytool \
   -importkeystore \
   -srckeystore   $CERTIFICATE_PATH \
   -srcstoretype  PKCS12 \
   -srcstorepass  $KEYSTORE_PASSWORD \
   -destkeystore  $KEYSTORE_PATH \
   -deststorepass $KEYSTORE_PASSWORD \
   -alias         $KEY_NAME \
   -destkeypass   $KEY_PASSWORD \
        || abort "Failed to import certificate"

# Set keystore file privileges
set_owner_and_group $KEYSTORE_PATH \
    || abort "Failed to set keystore privileges"

# Restart Tomcat
print_green "Restarting Tomcat..."
systemctl restart tomcat \
    || abort "Failed to restart Tomcat server"

print_bold_white "Done installing certificate!"
print_white "" # A blank line
