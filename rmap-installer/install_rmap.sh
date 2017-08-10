#!/bin/bash

# This script installs an RMap server.
# The account used to run the script must have sudo privileges.

# Only include this file once
[[ -n "$RMAP_RMAP_INCLUDED" ]] && return
RMAP_RMAP_INCLUDED=true

# install_common.sh and other initialization is performed in install_tomcat.sh
source install_tomcat.sh

print_bold_white "Installing RMap:"

################################################################################
# Perl modules and functions

ensure_installed cpanminus

# Install a Perl package if it is not yet installed.
# The name of the package is the only parameter.
function ensure_perl_installed
{
    NAME=$1
    [[ `perl -e "use $NAME;" 2>/dev/null` ]] &&
    {
        print_green "Installing '$NAME'..."
        cpanm $NAME &>> $LOGFILE \
            || abort "Could not install $NAME"
    }
}

ensure_perl_installed YAML
ensure_perl_installed Getopt::Long
ensure_perl_installed ExtUtils::MakeMaker
ensure_perl_installed Text::ParseWords
ensure_perl_installed Fcntl

ensure_installed perl-BerkeleyDB

################################################################################
# Set up NOID ID Minter

# Determine install type:
# There is either no previous installation (NEW),
# or there is a previous version that must be replaced (UPGRADE),
# or the current versios is already installed (NONE).
# Assume there can only be one previous version.
installed_version=`find /rmap -maxdepth 1 -name Noid-* -not -name *.back`
if [[ $installed_version == "" ]]; then
    print_green "Will perform initial NOID installation."
    INSTALL_TYPE=NEW
elif [[ $installed_version != $NOID_PATH ]]; then
    print_green "Will upgrade the NOID installation."
    INSTALL_TYPE=UPGRADE
else
    print_green "NOID installation is up to date."
    INSTALL_TYPE=NONE
fi

if [[ $INSTALL_TYPE != "NONE" ]]; then
    # For upgrades, save the current NOID folder as a backup
    if [[ $INSTALL_TYPE == "UPGRADE" ]]; then
        print_green "Backing up NOID data..."
        BACKUP_PATH=$installed_version.back
        if [[ -d $BACKUP_PATH ]]; then
            remove $BACKUP_PATH
        fi
        mv $installed_version $BACKUP_PATH &>> $LOGFILE \
            || abort "Could not rename NOID folder"
    fi

    # Download NOID distribution file
    if [[ -f $NOID_ZIP ]]; then
        remove $NOID_ZIP
    fi
    print_green "Downloading NOID..."
    wget --no-verbose $NOID_URI > /dev/null 2>> $LOGFILE \
        || abort "Could not download NOID"

    # Unzip, tweak and install NOID distribution
    print_green "Unzipping NOID..."
    tar -xf $NOID_ZIP -C $PARENT_DIR &>> $LOGFILE \
        || abort "Could not unzip NOID"
    # Install NOID for perl
    cp $NOID_PATH/lib/Noid.pm /usr/share/perl5 &>> $LOGFILE \
        || abort "Could not install NOID perl library"
    remove $NOID_ZIP
    # Remove the "tainted" flag from the NOID script
    sed "s,-Tw,-w," < $NOID_PATH/noid > $NOID_PATH/noid.fixed 2>> $LOGFILE \
        || abort "Could not modify NOID script"
    mv $NOID_PATH/noid.fixed $NOID_PATH/noid &>> $LOGFILE \
        || abort "Could not replace modified NOID script"
    chmod 775 $NOID_PATH/noid &>> $LOGFILE \
        || abort "Could not change permissions on NOID script"

    # Restore or create a NOID ID minter database, then test it
    # If update install, move saved folders back
    if [[ $INSTALL_TYPE == "UPGRADE" && -d $BACKUP_PATH/noiddb ]]; then
        print_green "Restoring NOID database..."
        cp -r $BACKUP_PATH/noiddb $NOID_PATH &>> $LOGFILE \
            || abort "Could not restore NOID database"
    else # install type is NEW
        print_green "Creating NOID database..."
        mkdir $NOID_PATH/noiddb &>> $LOGFILE \
            || abort "Could not create NOID database folder"
        pushd $NOID_PATH/noiddb &>> $LOGFILE
        perl $NOID_PATH/noid dbcreate .reeeeeeeeek &>> $LOGFILE \
            || abort "Could not create NOID database"
        popd &>> $LOGFILE
    fi
    [[ `perl $NOID_PATH/noid -f $NOID_PATH/noiddb mint 1 2>/dev/null` != "id:*" ]] \
        || abort "NOID minter failed initial test"

    # Create the NOID web service
    print_green "Creating NOID web service..."
    pushd $TOMCAT_PATH/webapps &>> $LOGFILE
    wget https://github.com/rmap-project/rmap/releases/download/v1.0.0-beta/noid.war \
        >> $LOGFILE 2>/dev/null \
            || abort "Could not download NOID web app"
    set_owner_and_group noid.war
    popd &>> $LOGFILE
    sed "s,NOIDPATH,$NOID_PATH,g" < noid.sh > $NOID_PATH/noid.sh 2>> $LOGFILE \
        || abort "Could not install NOID script"
    chmod 775 $NOID_PATH/noid.sh &>> $LOGFILE \
        || abort "Could not change permissions on NOID script"

    # Update ownership of all NOID files
    set_owner_and_group $NOID_PATH
fi

################################################################################
# RMap Configuration

print_green "Configuring RMap API and Account Manager web apps..."
# Make sure there is a properties folder
if [[ ! -d $RMAP_PROPS_FOLDER ]]; then
    mkdir $RMAP_PROPS_FOLDER &>> $LOGFILE \
        || abort "Could not create RMap properties folder"
fi

# TODO - Decide if this should be $IPADDR, $DOMAIN_NAME or "localhost"
URL=$DOMAIN_NAME
sed " \
    s,RMAPSERVERURL,$URL,; \
    s,MARIADBSERVERURL,$URL,; \
    s,DATABASENAME,$DATABASE_NAME,; \
    s,GRAPHDBSERVERURL,$URL,; \
    s,GOOGLEOAUTHKEY,$GOOGLE_OAUTH_KEY,; \
    s,GOOGLEOAUTHSECRET,$GOOGLE_OAUTH_SECRET,; \
    " \
    < $RMAP_PROPS_FILE > $RMAP_PROPS_FOLDER/$RMAP_PROPS_FILE 2>> $LOGFILE \
        || abort "Could not create RMap configuration file"

################################################################################
# RMap API

# TODO - Read version property from API POM file (if it exists):
#     /rmap/apache*/webapps/api/META_INF/maven/info.rmapproject/rmap-api/pom.properties
# Compare it to value in $RMAP_API_VERSION
# Install if file doesn't exist or if version is different.

print_green "Downloading RMap API web app..."
wget --no-verbose $RMAP_API_URI -O api.war 2>> $LOGFILE \
    || abort "Could not download RMap API web app"

print_green "Installing RMap API web app..."
mv api.war $TOMCAT_PATH/webapps &>> $LOGFILE \
    || abort "Could not install RMap API web app"
# Wait for WAR file to be processed and "api" folder to be created
API_PROP_PATH=$TOMCAT_PATH/webapps/api/WEB-INF/classes
while [[ ! -d "$API_PROP_PATH" ]]
do
    sleep 1
done

################################################################################
# RMap Account Manager

print_green "Downloading RMap Account Manager web app..."
wget --no-verbose $RMAP_APP_URI -O app.war 2>> $LOGFILE \
    || abort "Could not download RMap Account Manager web app"

print_green "Installing RMap Account Manager web app..."
mv app.war $TOMCAT_PATH/webapps/ROOT.war &>> $LOGFILE \
    || abort "Could not install RMap Account Manager web app"
# Wait for WAR file to be processed and "app" folder to be created
APP_PROP_PATH=$TOMCAT_PATH/webapps/ROOT/WEB-INF/classes
while [[ ! -d "$APP_PROP_PATH" ]]
do
    sleep 1
done

################################################################################
# Finalization

# Restart Tomcat so it reflects these changes
print_green "Restarting Tomcat..."
systemctl daemon-reload &>> $LOGFILE \
    || abort "Could not refresh services list"
systemctl stop tomcat &>> $LOGFILE \
    || abort "Could not stop Tomcat service"
systemctl start tomcat &>> $LOGFILE \
    || abort "Could not start Tomcat server"

if [[ -z $IS_UPGRADE ]]; then
    print_bold_white "Done installing RMap!"
else
    print_bold_white "Done upgrading RMap!"
fi
print_white "" # A blank line

