#!/bin/bash

# This script installs an RMap server.
# The account used to run the script must have sudo privileges.

source install_common.sh
# TODO - Restore the line below when development is complete
# install_common.sh and other initialization is performed in install_tomcat.sh
# source install_tomcat.sh


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

# If the NOID folder already exists, remove it.
# Remember this is now an upgrade so data will be copied back after install.
if [[ -d $NOID_PATH ]]; then
    print_green "Backing up NOID data..."
    IS_UPGRADE=true
    BACKUP_PATH=$PARENT_DIR/$NOID_DIR.back
    if [[ -d $BACKUP_PATH ]]; then
        remove $BACKUP_PATH
    fi
    mv $NOID_PATH $BACKUP_PATH &>> $LOGFILE \
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
cp $NOID_PATH/lib/Noid.pm /usr/local/share/perl5 &>> $LOGFILE \
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
if [[ -n $IS_UPGRADE && -d $BACKUP_PATH/noiddb ]]; then
    print_green "Restoring NOID database..."
    cp -r $BACKUP_PATH/noiddb $NOID_PATH &>> $LOGFILE \
        || abort "Could not restore NOID database"
else
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
pushd $TOMCAT_PATH/webapps > $LOGFILE
wget https://github.com/rmap-project/rmap/releases/download/v1.0.0-beta/noid.war \
    > $LOGFILE 2>/dev/null \
        || abort "Could not download NOID web app"
set_owner_and_group noid.war
popd > $LOGFILE
sed "s,NOIDPATH,$NOID_PATH,g" < noid.sh > $NOID_PATH/noid.sh 2>> $LOGFILE \
    || abort "Could not install NOID script"
chmod 775 $NOID_PATH/noid.sh &>> $LOGFILE \
    || abort "Could not change permissions on NOID script"

# Update ownership of all NOID files
set_owner_and_group $NOID_PATH


################################################################################
# RMap API
print_green "Downloading RMap API web app..."
wget --no-verbose \
    https://github.com/rmap-project/rmap/releases/download/v1.0.0-beta/rmap-api-1.0.0-beta.war \
    2>> $LOGFILE \
        || abort "Could not download RMap API web app"
mv rmap-api-1.0.0-beta.war $TOMCAT_PATH/webapps/api.war &>> $LOGFILE \
    || abort "Could not install RMap API web app"
# TODO - How best to wait for api folder to be created?
sleep 2
API_PROP_PATH=$TOMCAT_PATH/webapps/api/WEB-INF/classes
# TODO - Move the IPADDR definition to the common script?
IPADDR=`hostname -I 2>> $LOGFILE | tr -d '[:space:]'` \
    || abort "Could not find IP address"
sed "s,RMAPSERVERURL,$IPADDR," \
    < rmapapi.properties > $API_PROP_PATH/rmapapi.properties 2>> $LOGFILE \
        || abort "Could not modify RMap API properties file"
sed "s,RMAPSERVERURL,$IPADDR,; s,MYSQLSERVERURL,$IPADDR," \
    < rmapauth.properties > $API_PROP_PATH/rmapauth.properties 2>> $LOGFILE \
        || abort "Could not modify RMap Authorization properties file"
sed "s,GRAPHDBSERVERURL,$IPADDR," \
    < rmapcore.properties > $API_PROP_PATH/rmapcore.properties 2>> $LOGFILE \
        || abort "Could not modify RMap Core properties file" 


################################################################################
# RMap Account Manager
print_yellow "   RMap Account Manager is not currently installed!"


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
    print_white "Done installing RMap!"
else
    print_white "Done upgrading RMap!"
fi
print_white "" # A blank line

