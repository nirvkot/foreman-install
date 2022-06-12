#!/bin/bash


REQUIRED_PACKAGES="podman yum-utils"
DATADIR="/data/repos"
NGINX_DIR="/etc/nginx_autoindex"
NGINX_CONFIG="$NGINX_DIR/nginx.conf"
RHEL_RELEASE_EUS="8.4"
NGINX_PORT="80"
NGINX_CONTAINER_NAME="nginx-autoindex"
NGINX_CONTAINER_IMAGE="docker.io/library/nginx:latest"

# USE THIS LIST TO DOWNLOAD REPOS WITH EUS AND E4S ENABLED-DISTROS (RHEL FOR SAP SOLUTIONS) 

REPOLIST_BASE="rhel-8-for-x86_64-appstream-rpms \
              rhel-8-for-x86_64-baseos-rpms"

REPOLIST_EUS="rhel-8-for-x86_64-appstream-e4s-rpms \
             rhel-8-for-x86_64-appstream-eus-rpms \
             rhel-8-for-x86_64-appstream-rpms \
             rhel-8-for-x86_64-baseos-e4s-rpms \
             rhel-8-for-x86_64-baseos-eus-rpms \
             rhel-8-for-x86_64-baseos-rpms \
             rhel-8-for-x86_64-highavailability-e4s-rpms \
             rhel-8-for-x86_64-highavailability-eus-rpms \
             rhel-8-for-x86_64-highavailability-rpms \
             rhel-8-for-x86_64-sap-netweaver-e4s-rpms \
             rhel-8-for-x86_64-sap-netweaver-eus-rpms \
             rhel-8-for-x86_64-sap-netweaver-rpms \
             rhel-8-for-x86_64-sap-solutions-e4s-rpms \
             rhel-8-for-x86_64-sap-solutions-eus-rpms \
             rhel-8-for-x86_64-sap-solutions-rpms"


# USE THIS LIST TO DOWNLOAD ALL LATEST PACKAGES FROM REPO (8.5) 
# NETWEAVER REPOS SHOULD BE HERE

REPOLIST_STD="rhel-8-for-x86_64-appstream-rpms \
             rhel-8-for-x86_64-baseos-rpms \
             rhel-8-for-x86_64-highavailability-rpms \
             rhel-8-for-x86_64-sap-netweaver-rpms \
             fast-datapath-for-rhel-8-x86_64-rpms \
             advanced-virt-for-rhel-8-x86_64-rpms \
             openstack-16.2-cinderlib-for-rhel-8-x86_64-rpms \
             rhceph-5-tools-for-rhel-8-x86_64-rpms \
             rhceph-4-tools-for-rhel-8-x86_64-rpms \
             ansible-2.9-for-rhel-8-x86_64-rpms \
             rhvh-4-for-rhel-8-x86_64-rpms \
             jb-eap-7.4-for-rhel-8-x86_64-rpms \
             rhv-4-mgmt-agent-for-rhel-8-x86_64-rpms \
             openstack-16.2-for-rhel-8-x86_64-rpms"

echo "Preparing folder for sync and share"
mkdir -p $DATADIR
echo "Setting up selinux context for our data directory"
semanage fcontext -a -t httpd_sys_content_t "$DATADIR(/.*)?"

echo "Setting up Selinux boolean to allow an access to nginx"
setsebool -P virt_sandbox_share_apache_content 1

echo "Enabling base repos to install required packages"
for repos in $REPOLIST_BASE;
  do subscription-manager repos --enable=$repos;
done;

echo "Installing neccesary requirements for reposync"

dnf install -y $REQUIRED_PACKAGES

echo "Setting up rhel release enable EUS and E4S repos"

subscription-manager release --set=$RHEL_RELEASE_EUS

echo "Starting sync EUS and E4S REPOS"
for repos in $REPOLIST_EUS;
  do reposync --repo=$repos -p $DATADIR --download-metadata;
done;

echo "Unset release for all packages inside the appstream and baseos"
subscription-manager release --unset

echo "Starting sync standard REPOS"
for repos in $REPOLIST_STD;
  do reposync --repo=$repos -p $DATADIR --download-metadata;
done;

echo "Setting up dirs for nginx config"
mkdir -p $NGINX_DIR

echo "Generating configuration for nginx-autoindex"

tee $NGINX_CONFIG > /dev/null <<EOT
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;
include /usr/share/nginx/modules/*.conf;
events {
    worker_connections 1024;
}
http {
    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;
    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;
    include /etc/nginx/conf.d/*.conf;
    server {
        listen       80 default_server;
        listen       [::]:80 default_server;
        server_name  _;
        root         /usr/share/nginx/html;
        include /etc/nginx/default.d/*.conf;
        location / {
          expires -1;
          autoindex on;
    }
    }
}
EOT


echo "Opening TCP port for nginx and setting up selinux parameter"
firewall-cmd --add-port=$NGINX_PORT/tcp --permanent
firewall-cmd --reload
semanage port -a -t http_port_t -p tcp $NGINX_PORT

echo "Starting up nginx-autoindex container for exposing our repos folder"
podman run -itd --restart=always --name $NGINX_CONTAINER_NAME -p $NGINX_PORT:80 -v $NGINX_CONFIG:/etc/nginx/nginx.conf -v $DATADIR:/usr/share/nginx/html -d $NGINX_CONTAINER_IMAGE