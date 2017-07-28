README for installing an RMap server or its individual components.

Draft release as of 7/28/2017

Description:
* This installation package deploys several components that together constitute an RMap server.
* Those components include the Java JDK, Apache Tomcat, Ontotext GraphDB, MariaDB and RMap.
* All components are currently installed, but installer development is not yet finalized.
* In particular, the following features are not completed:
  * The RMap component does not yet successfully communicate with MariaDB.
  * The OAuth functionality of the RMap component is not yet implemented.
* Individual components can be installed separately.
* The installers can be re-run to upgrade an existing installation.

System Requirements
* This installer works with any CentOS version 7 distribution available at https://www.centos.org/download/.
* It does not work with the Docker containers available at https://hub.docker.com/_/centos/.
* The system must have internet access in order to download distributables and test the installation.
* A domain name must exist and be pointing to the system.
* An SSL certificate must be supplied or generated using an included script to support HTTPS access.

Installated files
* Server components will be installed under an /rmap directory.
* All installed files will be owned by the user that runs the install script.

Tomcat
* Tomcat can be installed separately with install_tomcat.sh.
* A service is enabled so that Tomcat starts automatically when the system reboots.
* The firewall is enabled and port forwarding set up so Tomcat will function correctly.
* When installation is done, the main Tomcat page will be at /tomcat on the server.

GraphDB
* GraphDB can be installed separately with install_graphdb.sh.
* A service is enabled so that GraphDB starts automatically when the system reboots.
* The firewall is enabled and ports permanently opened so GraphDB will function correctly.
* When installation is done, the main GraphDB page will be at port 7200 on the server.
* The server will have an "rmap" repository.
* The server will have an "rmap" user with password "rmap" (change it!)

MariaDB
* MariaDB can be installed separately with install_mariadb.sh.
* The MariaDB server is installed, enabled and started.
* During the initial installation, some security measures are performed on the database.
* During the initial installation, an "rmap" database is added and initial tables are created.
* During the initial installation, the local user "rmap" is given access to the "rmap" database.

RMap
* The RMap components can be installed separately with install_rmap.sh.
* When installation is done, the RMap web account manager will be at the root of the server.
* When installation is done, the RMap API will be at /api on the server.

Directions:
* The installation scripts must be run by a user with sudo privileges.
* The installation scripts must be run from the directory containing the scripts.
* Edit the properties in configuration.sh to:
     Set the site domain name
     Specify the certificate file location
     Specify some passwords to be used when creating components
* If you would like to generate a signed certificate to allow HTTPS access:
     sudo ./create_letsencrypt_cert.sh
* If you would like to create a sudo user named "rmap", issue this command:
     sudo ./create_rmap_user.sh
* Once logged in as the sudo user who will own the deployed files, issue:
     sudo ./install_tomcat.sh
  and/or:
     sudo ./install_graphdb.sh
  and/or:
     sudo ./install_mariadb.sh
  and/or:
     sudo ./install_rmap.sh
  OR (for all components):
     sudo ./install_all.sh
* During the initial installation, install the SSL certificate with this command:
     sudo ./install_certificate.sh