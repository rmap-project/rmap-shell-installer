#!/bin/bash

# Installs the current Java JDK package in support of an RMap server.
# The account used to run the script must have sudo privileges.

# Only include this file once
[[ -n "$RMAP_JAVA_INCLUDED" ]] && return
RMAP_JAVA_INCLUDED=true

source install_common.sh

print_bold_white "Installing Java:"

confirm_sudo

ensure_root_folder

ensure_installed wget

################################################################################

# Evaluate any previous version of Java (assume there could only be one)
installed_version=`find /rmap -maxdepth 1 -name jdk*`

if [[ $installed_version == $JAVA_PATH ]]; then
    print_bold_white "Java installation is up to date"
else
    if [[ $installed_version != "" ]]; then
        print_green "Deleting previous version..."
        remove $installed_version
    fi

    print_green "Downloading Java..."
    if [[ -f $JDK_ZIP ]]; then
        remove $JDK_ZIP
    fi
    wget --no-cookies --no-check-certificate --no-verbose \
        --header "Cookie: oraclelicense=accept-securebackup-cookie" \
        $JDK_URI &>> $LOGFILE \
            || abort "Could not download Java"

    print_green "Installing Java..."
    tar -xf $JDK_ZIP -C $PARENT_DIR &>> $LOGFILE \
        || abort "Could not unzip Java"
    remove $JDK_ZIP
    set_owner_and_group $JAVA_PATH \
        || abort "Could not set owner of JDK folder"

    print_bold_white "Done installing Java!"
fi

print_white "" # Blank line

