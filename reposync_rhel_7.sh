#!/bin/bash


REQUIRED_PACKAGES="docker yum-utils createrepo"
DATADIR="/data/repos"
NGINX_DIR="/etc/nginx_autoindex"
NGINX_CONFIG="$NGINX_DIR/nginx.conf"
RHEL_RELEASE_EUS="7.7"
NGINX_PORT="80"
NGINX_CONTAINER_NAME="nginx-autoindex"
NGINX_CONTAINER_IMAGE="docker.io/library/nginx:latest"

# USE THIS LIST TO DOWNLOAD REPOS WITH EUS AND E4S ENABLED-DISTROS (RHEL FOR SAP SOLUTIONS)



REPOLIST_BASE="rhel-7-server-rpms \
              rhel-7-server-optional-rpms"
REPOLIST_STD="rhel-7-server-rpms \
              rhel-7-server-optional-rpms \
              rhel-7-server-extras-rpms \
              rhel-server-rhscl-7-rpms \
              rhel-7-server-dotnet-rpms \
              rhel-7-server-devtools-rpms \
              rhel-7-server-supplementary-rpms"


echo "Preparing folder for sync and share"
mkdir -p $DATADIR

echo "enabling RHEL 7 repos"
for repos in $REPOLIST_BASE;
  do subscription-manager repos --enable=$repos;
done;

echo "Installing neccesary requirements for reposync"

yum install -y $REQUIRED_PACKAGES
echo "Unset release for all packages inside the appstream and baseos"

echo "Starting sync standard REPOS"
for repos in $REPOLIST_STD;
  do reposync --repo=$repos -p $DATADIR --download-metadata --downloadcomps;
done;

echo "Creating repo metadata for rhel 7 STD"
for repos in $REPOLIST_STD;
  do createrepo -v $DATADIR/$repos -g $DATADIR/$repos/comps.xml;
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
systemctl enable docker --now

echo "Starting up nginx-autoindex container for exposing our repos folder"
docker run -itd --restart=always --name $NGINX_CONTAINER_NAME -p $NGINX_PORT:80 -v $NGINX_CONFIG:/etc/nginx/nginx.conf -v $DATADIR:/usr/share/nginx/html -d $NGINX_CONTAINER_IMAGE