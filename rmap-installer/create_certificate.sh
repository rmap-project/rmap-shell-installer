#!/bin/bash

# Creates a certificate and keystore to support SSL for this server.
# The account used to run the script must have sudo privileges.

################################################################################
# Initialization

# install_common.sh and other initialization is performed in install_tomcat.sh
source install_tomcat.sh

ensure_installed epel-release
ensure_installed certbot

# TODO - Have user supply domain name
DOMAIN=rmap.trumbore.com
ALIAS=tomcat
KEY_PASSWORD=changeit
STORE_PASSWORD=changeit
KEYSTORE=$TOMCAT_PATH/conf/localhost-rsa.jks
LE_PATH=/etc/letsencrypt/live/$DOMAIN

################################################################################
# Generate certificate and import into keystore

# If the keystore file exists and contains the certificate, we're done.
# TODO - See if the certificate has expired.  If so, renew it with certbot.
if [[ -f $KEYSTORE ]]; then
    $JAVA_PATH/bin/keytool -list \
        -alias $ALIAS \
        -keystore $KEYSTORE \
        -storepass $STORE_PASSWORD \
        &>> $LOGFILE \
            && {
                print_yellow "   Certificate already exists in keystore!"
                exit
            }
fi

# Generate a certificate by connecting to our (running) Tomcat server
print_green "Generating certificate..."
certbot certonly --webroot -w $TOMCAT_PATH/webapps/tomcat -d $DOMAIN \
    || abort "Failed to generate certificate"

# Convert certificate to form needed to import into keystore
print_green "Converting certificate..."
openssl pkcs12 -export \
    -in $LE_PATH/fullchain.pem \
    -inkey $LE_PATH/privkey.pem \
    -out $LE_PATH/pkcs.p12 \
    -passout pass:$KEY_PASSWORD \
    -name tomcat \
        || abort "Failed to convert certificate"

# Add certificate to keystore, possibly creating keystore file
print_green "Importing certificate into keystore..."
$JAVA_PATH/bin/keytool \
   -importkeystore \
   -deststorepass $STORE_PASSWORD \
   -destkeypass $KEY_PASSWORD \
   -destkeystore $KEYSTORE \
   -srckeystore $LE_PATH/pkcs.p12 \
   -srcstoretype PKCS12 \
   -srcstorepass $STORE_PASSWORD \
   -alias tomcat \
        || abort "Failed to import certificate"

# Set keystore file privileges
set_owner_and_group $KEYSTORE \
    || abort "Failed to set keystore privileges"

# Restart Tomcat
systemctl restart tomcat \
    || abort "Failed to restart Tomcat server"

print_white "Done creating certificate!"
echo # A blank line
