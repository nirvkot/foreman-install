#!/bin/bash
firewall-cmd --add-port="53/udp" --add-port="53/tcp" \
	--add-port="67/udp" --add-port="69/udp" \
	--add-port="80/tcp" --add-port="443/tcp" \
	--add-port="5647/tcp" --add-port="8000/tcp" \
	--add-port="9090/tcp" --add-port="8140/tcp";
firewall-cmd --runtime-to-permanent;
#-----------------------------------
dnf clean all;
dnf localinstall https://yum.theforeman.org/releases/3.2/el8/x86_64/foreman-release.rpm -y;
dnf localinstall https://yum.theforeman.org/katello/4.4/katello/el8/x86_64/katello-repos-latest.rpm -y;
dnf install centos-release-ansible-29 -y;
dnf localinstall https://yum.puppet.com/puppet7-release-el-8.noarch.rpm -y;
dnf module reset ruby -y;
dnf module enable ruby:2.7 -y;
dnf config-manager --set-enabled powertools;
dnf module enable postgresql:12 -y;
dnf update -y;
dnf install foreman-installer-katello -y;
#-------------------------------------
foreman-installer --scenario katello \
--foreman-initial-organization "LocalOrg01" \
--foreman-initial-location "Somewhere" \
--foreman-initial-admin-username katello-admin \
--foreman-initial-admin-password '123qweASD'
