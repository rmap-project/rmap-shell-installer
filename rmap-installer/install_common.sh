#!/bin/bash

# Defines some variables and functions that are used by
# other scripts in the RMap installer.
# Calling this script directly will not install anything.

# Only include this file once
[[ -n "$RMAP_COMMON_INCLUDED" ]] && return
RMAP_COMMON_INCLUDED=true

###############################################################################
# Component versions and locations

# Java JDK
JDK_DIR=jdk1.8.0_131
JDK_ZIP=jdk-8u131-linux-x64.tar.gz
JDK_URI=http://download.oracle.com/otn-pub/java/jdk/8u131-b11/d54c1d3a095b4ff2b6607d096fa80163/$JDK_ZIP

#Tomcat
TOMCAT_DIR=apache-tomcat-8.0.36
TOMCAT_ZIP=apache-tomcat-8.0.36.tar.gz
TOMCAT_URI=https://archive.apache.org/dist/tomcat/tomcat-8/v8.0.36/bin/$TOMCAT_ZIP
#TOMCAT_DIR=apache-tomcat-8.5.15
#TOMCAT_ZIP=apache-tomcat-8.5.15.tar.gz
#TOMCAT_URI=https://archive.apache.org/dist/tomcat/tomcat-8/v8.5.15/bin/$TOMCAT_ZIP

# GraphDB
GRAPHDB_DIR=graphdb-free-8.0.6
GRAPHDB_ZIP=graphdb-free-8.0.6-dist.zip
GRAPHDB_URI=http://download.ontotext.com/owlim/6497f7fa-15e0-11e7-84d0-06278a02ff7a/$GRAPHDB_ZIP

# MySQL
DATABASE_NAME=rmap

# NOID
NOID_DIR=Noid-0.424
NOID_ZIP=Noid-0.424.tar.gz
NOID_URI=http://search.cpan.org/CPAN/authors/id/J/JA/JAK/$NOID_ZIP

# RMAP
RMAP_API_WAR=rmap-api-1.0.0-beta.war
RMAP_APP_WAR=rmap-webapp-1.0.0-beta.war
RMAP_DOWNLOAD=https://github.com/rmap-project/rmap/releases/download/v1.0.0-beta
RMAP_API_URI=$RMAP_DOWNLOAD/$RMAP_API_WAR
RMAP_APP_URI=$RMAP_DOWNLOAD/$RMAP_APP_WAR

# Installation folder
PARENT_DIR=/rmap

# Installation paths
JAVA_PATH=$PARENT_DIR/$JDK_DIR
TOMCAT_PATH=$PARENT_DIR/$TOMCAT_DIR
GRAPHDB_PATH=$PARENT_DIR/$GRAPHDB_DIR
NOID_PATH=$PARENT_DIR/$NOID_DIR

###############################################################################
# Printing and logging

# Variables used to display colored text
R=`tput setaf 1`
G=`tput setaf 2`
Y=`tput setaf 3`
W=`tput sgr0`

# Initialize the named log file to be empty
LOGFILE=installer.log
echo -n "" > $LOGFILE

# Prints a message in green text and adds it to the log file
function print_green
{
    echo "${G}$1${W}"
    echo "${G}$1${W}" >> $LOGFILE
}

# Prints a message in yellow text and adds it to the log file
function print_yellow
{
    echo "${Y}$1${W}"
    echo "${Y}$1${W}" >> $LOGFILE
}

# Prints a message in yellow text without an EOL and adds it to the log file.
function print_yellow_noeol
{
    echo -n "${Y}$1${W}"
    echo -n "${Y}$1${W}" >> $LOGFILE
}

# Prints a message in red text and adds it to the log file
function print_red
{
    echo "${R}$1${W}"
    echo "${R}$1${W}" >> $LOGFILE
}

# Prints a message in white text and adds it to the log file
function print_white
{
    echo "${W}$1"
    echo "${W}$1" >> $LOGFILE
}

###############################################################################
# Other initialization

# Get the ID of the current user
USERID=`logname`

# Get the IP Address of this computer
IPADDR=`hostname -I 2>> $LOGFILE | tr -d '[:space:]'` \
    || abort "Could not find IP address"

# Make sure yum is ready to install new modules
print_green "Updating yum cache..."
yum makecache fast &>> $LOGFILE \
    || abort "Could not update yum cache"

# Set permissions on log file (file should exist and varables be set by now)
chown $USERID $LOGFILE
chgrp $USERID $LOGFILE
chmod 664 $LOGFILE

###############################################################################
# Utility functions

# Prints a message and exits if the script was not run with sudo privileges.
function confirm_sudo
{
    # Verify that the script can sudo, or print message and quit
    if [[ $EUID -ne 0 ]]; then
        print_red "This script must be run as root (sudo ./install_gaphdb.sh)"
        exit 1
    fi
}

# Prints an error message and the source file and line number, then exits.
# The message string is the only parameter.
function abort
{
    print_red "Aborting at line ${BASH_LINENO[0]} in script ${BASH_SOURCE[1]} due to error:"
    print_red "   $1 ${W}"
    exit 1
}

# Install a CentOS package if it is not yet installed.
# The name of the package is the only parameter.
function ensure_installed
{
    NAME=$1
    if [[ `rpm -q $NAME` == "package $NAME is not installed" ]]; then
        print_green "Installing '$NAME'..."
        yum -y install $NAME &>> $LOGFILE \
             || abort "Could not install $NAME"
    fi
}

# Remove the named folder or directory and its contents.
# The file or folder to remove is the only parameter.
function remove
{
    rm -rf $1 &>> $LOGFILE \
        || abort "Could ot remove $1"
}

# Recursively sets the owner and group for a folder to be
# the user that is running the script.
# The full path to the folder is the only parameter.
function set_owner_and_group
{
    chown -R $USERID $1 &>> $LOGFILE \
        || abort "Could not change folder owner"
    chgrp -R $USERID $1 &>> $LOGFILE \
        || abort "Could not change folder group"
}

# Confirms the existance of, or creates, the root folder for server files.
function ensure_root_folder
{
    if [[ ! -d $PARENT_DIR ]]; then
        print_green "Creating root rmap folder..."
        mkdir $PARENT_DIR &>> $LOGFILE \
            || abort "Could not create folder $PARENT_DIR"
        chmod 775 $PARENT_DIR &>> $LOGFILE \
            || abort "Could not set permissions on $PARENT_DIR"
        set_owner_and_group $PARENT_DIR
    fi
}

# Confirms the existance of, or creates, a sub-folder of the root folder.
# The name of the sub-folder is the first parameter.
# The name of the component that needs the folder is the second parameter.
function ensure_sub_folder
{
    if [[ ! -d $PARENT_DIR/$1 ]]; then
        print_green "Creating folder for ${2}..."
        mkdir $PARENT_DIR/$1 &>> $LOGFILE \
            || abort "Could not create ${2} folder"
        set_owner_and_group $PARENT_DIR/$1
    fi
}

# If the identified service is running, it is stopped.
# The name of the serivce is the only parameter.
function ensure_service_stopped
{
    if [[ `systemctl status $1 &>> $LOGFILE | grep "running" | wc -l` == "1" ]]; then
        print_green "Stopping $1 service..."
        systemctl stop $1 &>> $LOGFILE \
            || abort "Could not stop $1 service"
    fi
}

