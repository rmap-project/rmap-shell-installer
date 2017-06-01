#!/bin/bash

# This script installs all components needed to support an RMap server.
# The account used to run the script must have sudo privileges.

source install_graphdb.sh

source install_mysql.sh

# Also installs Java and Tomcat
# source install_rmap.sh
