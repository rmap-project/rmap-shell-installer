#!/bin/bash

# This script installs all components needed to support an RMap server.
# The account used to run the script must have sudo privileges.

# install_common.sh and other initialization is performed in install_tomcat.sh
source install_tomcat.sh

source install_graphdb.sh

source install_mariadb.sh

source install_rmap.sh
