README for installing an RMap server or its individual components.

Draft release as of 8/24/2017

Description:
* This installation package deploys several components that together constitute an RMap server.
* Those components include the Java JDK, Apache Tomcat, Ontotext GraphDB, MariaDB and RMap.
* Installations for all components are working, but installer development is ongoing.
* Individual components can be installed separately, though presently only on the same system.
* The installers can be re-run to upgrade an existing installation.

System Requirements
* This installer works with any CentOS version 7 distribution available at https://www.centos.org/download/.
* It does not work with the Docker containers available at https://hub.docker.com/_/centos/.
* The system must have internet access in order to download distributables and test the installation.
* A domain name must exist and be pointing to the system.
* To support HTTPS, an SSL certificate must be supplied or generated using the included script.
* For deployments on cloud instances, the following ports must be open: 80, 443.
* For multi-system deployments, these ports also need to be opened: 7200 (GraphDB), 3306 (MariaDB).

Installated files
* Server components will be installed under the /rmap directory.
* All installed files will be owned by the user that runs the install script.

Tomcat
* Tomcat can be installed separately with install_tomcat.sh.
* A service is enabled so that Tomcat starts automatically when the system reboots.
* The firewall is enabled and port forwarding set up so Tomcat will function correctly.
* When installation is done, the main Tomcat page will be at /tomcat on the server.
* Once Tomcat is running, install_certificate.sh can be used to add an SSL certificate to its keystore.

GraphDB
* GraphDB can be installed separately with install_graphdb.sh.
* A service is enabled so that GraphDB starts automatically when the system reboots.
* When installation is done, the main GraphDB page will be at port 7200 on the server.
* By default, the server will have an "rmap" repository.
* By default, the server will have an "rmap" user with password "rmap".

MariaDB
* MariaDB can be installed separately with install_mariadb.sh.
* The MariaDB server is installed, enabled and started.
* During the installation, some security measures are performed on the database.
* By default, during the installation an "rmap" database is added and initial tables are created.
* By default, during the installation the user "rmap" is given access to the "rmap" database.

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
     Specify the OAuth key/secret combinations that will used to authenticate new users
        Additional requirements for each OAuth provider are listed in configuration.sh
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
* Either place your existing certificate file at the location specified in configuration.sh
  OR (if you need to generate a signed SSL certificate):  With Tomcat still running:
     sudo ./create_letsencrypt_cert.sh
* Install the SSL certificate with this command:
     sudo ./install_certificate.sh