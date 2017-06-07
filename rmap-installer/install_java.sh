#!/bin/bash

# Installs the Java JDK package from
# the zip file that is included in the install package.
# The account used to run the script must have sudo privileges.

# Only include this file once
[[ -n "$RMAP_JAVA_INCLUDED" ]] && return
RMAP_JAVA_INCLUDED=true

source install_common.sh

confirm_sudo

ensure_root_folder

ensure_installed wget

################################################################################

# If JDK content doesn't exist, download and unzip it
if [[ ! -d $JAVA_PATH ]]; then
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

    print_white "Done installing Java!"
    print_white "" # Blank line
fi

