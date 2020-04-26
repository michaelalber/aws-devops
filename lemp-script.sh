#!/bin/bash
#
# Web Server Dependency Installer Script for CentOS 7
#
#Created by Matthew Guillot
#
#--------------------------------------

# Based on a template by BASH3 Boilerplate v2.3.0
# http://bash3boilerplate.sh/#authors
#
# The MIT License (MIT)
# Copyright (c) 2013 Kevin van Zonneveld and contributors
# You are not obligated to bundle the LICENSE file with your b3bp projects as long
# as you leave these references intact in the header comments of your source files.

# Exit on error. Append "|| true" if you expect an error.
set -o errexit
# Exit on error inside any functions or subshells.
set -o errtrace
# Do not allow use of undefined vars. Use ${VAR:-} to use an undefined VAR
set -o nounset
# Catch the error in case mysqldump fails (but gzip succeeds) in `mysqldump |gzip`
set -o pipefail
# Turn on traces, useful while debugging but commented out by default
# set -o xtrace

# Web Application Paths

# Path to Production
WEBAPPPROD_PATH="/var/www/html"

#New App/Developer User Account Credentials
LOCALUSER="developer"
LOCALUSERPASS="PASSWORD_GOES_HERE"
LOCALUSERGROUP="phpdev"

# Instance hostname
DIHOSTNAME='staging-server'

echo ">>> Starting install script"

yum -y update

echo ">>> Installing Web server stack Dependencies (Nginx, PHP-FPM, PHP v7.2+, Laravel Installer, NodeJS w/ npm and yarn)"

rpm -Uvh https://mirror.webtatic.com/yum/el7/epel-release.rpm
rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
curl --silent --location https://rpm.nodesource.com/setup_9.x | sudo bash -

yum -y install -y gcc-c++ make
yum install -y nginx php72w php72w-common php72w-mysql php72w-mcrypt php72w-gd php72w-fpm php72w-dom php72w-mbstring php72w-opcache php72w-devel git
yum -y install nodejs
npm install yarn -g

echo "Creating user $LOCALUSER..."
useradd -m $LOCALUSER
usermod --password $(echo $LOCALUSERPASS | openssl passwd -1 -stdin) $LOCALUSER
groupadd $LOCALUSERGROUP
usermod -a -G $LOCALUSERGROUP $LOCALUSER

echo "Setting up Nginx configuration..."

mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

echo "Setting up website document root path..."

mkdir -p $WEBAPPPROD_PATH

echo "Installing Composer..."
curl -sS https://getcomposer.org/installer | php -- --install-dir=/home
mv /home/composer.phar /usr/sbin/composer

export PATH=$PATH:~/.composer/bin
cat "export PATH=$PATH:~/.composer/bin:~/.composer/vendor/bin" >> ~/.bashrc

echo "Setting up composer for $LOCALUSER account..."
sudo -u $LOCALUSER -H sh -c "cd ~;composer require 'laravel/installer';"
cat "export PATH=$PATH:/home/$LOCALUSER/.composer/bin:/home/$LOCALUSER/.composer/vendor/bin" >> "/home/$LOCALUSER/.bashrc"



echo "Setting file permissions for Equidy Login files..."
find $WEBAPPPROD_PATH -type d -exec chmod 0775 {} \;
find $WEBAPPPROD_PATH -type f -exec chmod 0664 {} \;
setfacl -Rdm g::rwx $WEBAPPPROD_PATH
chown -R :$LOCALUSER $WEBAPPPROD_PATH
chmod -R g+rwxs $WEBAPPPROD_PATH
usermod -G $LOCALUSERGROUP nginx
usermod -G $LOCALUSERGROUP apache


#Allow file permissions necessary to serve website/app files
echo "/usr/sbin/setenforce permissive" >> /etc/rc.local
chmod +x /etc/rc.local
setenforce permissive

echo ">>> Configuring PHP-FPM"
sed -i "s/;listen.owner = .*/listen.owner = nginx/g" /etc/php-fpm.d/www.conf
sed -i "s/;listen.group = .*/listen.group = equidy/g" /etc/php-fpm.d/www.conf
sed -i "s/;listen.mode = .*/listen.mode = 0660/g" /etc/php-fpm.d/www.conf
sed -i "s/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm\/php-fpm.sock/g" /etc/php-fpm.d/www.conf
echo "cgi.fix_pathinfo=0" >> /etc/php.ini
systemctl enable php-fpm.service
systemctl start php-fpm.service

echo "Enabling and Starting Nginx...";
systemctl enable nginx
systemctl start nginx

hostnamectl set-hostname $DIHOSTNAME
echo "Web server dependency installation has finished! :)"
history -c
cd ~
rm -- "$0"
