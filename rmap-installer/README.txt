README for installing an RMap server or its individual components.

Draft release as of 6/16/2017

Description:
* This installation package deploys several components that together constitute an RMap server.
* Those components include the Java JDK, Apache Tomcat, Ontotext GraphDB, MySQL and RMap.
* All components are currently installed, but the install process is not yet finalized.
* In particular, the OAuth functionality of the RMap component is not yet implemented.
* Individual components can be installed separately, and on different computers.

System Requirements
* This installer works with any CentOS version 7 distribution available at https://www.centos.org/download/.
* It does not work with the Docker containers available at https://hub.docker.com/_/centos/.
* The system must have internet access in order to download distributables and test the installation.

Installated files
* All installed files will be stored under an /rmap directory.
* The installation scripts must be run by a user with sudo privileges.
* All installed files will be owned by that sudo user.

Tomcat
* Tomcat will eventually be installed with RMap, but can be installed separately with install_tomcat.sh.
* A service is enabled so that Tomcat starts automatically when the system reboots.
* The firewall is enabled and port forwarding set up so Tomcat will function correctly.
* The installer can be re-run to upgrade an existing installation.
* When installation is done, point a web browser to the server's (default port 80).

GraphDB
* GraphDB can be installed separately with install_graphdb.sh.
* A service is enabled so that GraphDB starts automatically when the system reboots.
* The firewall is enabled and ports permanently opened so GraphDB will function correctly.
* The installer can be re-run to upgrade an existing installation.
* When installation is done, point a web browser to the server's port 7200.
* The server will have an "rmap" repository.
* The server will have an "rmap" user with password "rmap" (change it!)

MySQL
* MySQL can be installed separately with install_mysql.sh.
* The MariaDB server is installed, enabled and started.
* No firewall changes are made at this time.
* During the initial installation, some security measures are taken.
* During the initial installation, an "rmap" database is added and initial tables are created.
* During the initial installation, the local user "rmap" is given access to the "rmap" database.

RMap
* The RMap components can be installed separately with install_rmap.sh.
* Development is continuing on the RMap API and RMap web authoring component installations.

Directions:
* If you would like to create a sudo user named "rmap", issue this command:
     sudo ./create_rmap_user.sh
* If you would like to generate a signed certificate to allow HTTPS access:
     sudo ./create_certificate.sh
* Once logged in as the user who will own the deployed files, issue:
     sudo ./install_tomcat.sh
  and/or:
     sudo ./install_graphdb.sh
  and/or:
     sudo ./install_mysql.sh
  and/or:
     sudo ./install_rmap.sh
  or (for all components):
     sudo ./install_all.sh
