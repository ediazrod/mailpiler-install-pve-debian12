#!/bin/bash

#Some variables to modifi:

PILER_DOMAIN="piler.mydomain.com"
SMARTHOST="192.168.50.2"
# This is you host that send e-mail for imap auth
PILER_VERSION="1.4.4"
## Manticore="6.3"
PHP_VERSION="8.2"

HOSTNAME=$(hostname -f)

echo "Ensure your Hostname is set to your Piler FQDN!"

echo $HOSTNAME

if 
    [ "$HOSTNAME" != "$PILER_DOMAIN" ]
then
        echo "Hostname doesn't match Piler_Domain! Check install.sh, /etc/hosts, /etc/hostname." && exit
else
        echo "Hostname matches PILER_DOMAIN, so starting installation."
fi

apt install -y gpg apt-transport-https lsb-release

wget -q https://packages.sury.org/php/apt.gpg -O- | apt-key add -
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list

apt update && apt full-upgrade -y

apt install -y mc sysstat build-essential libwrap0-dev libpst-dev tnef libytnef0-dev unrtf catdoc libtre-dev tre-agrep poppler-utils libzip-dev unixodbc libpq5 software-properties-common libpoppler-dev openssl libssl-dev memcached telnet nginx mariadb-server default-libmysqlclient-dev gcc libwrap0 libzip4 latex2rtf latex2html catdoc tnef libpq5 zipcmp zipmerge ziptool libsodium23

# apt update && apt install -y php7.4-fpm php7.4-common php7.4-ldap php7.4-mysql php7.4-cli php7.4-opcache php7.4-phpdbg php7.4-gd php7.4-memcache php7.4-json php7.4-readline php7.4-zip
# The default install is 8.2 for php
apt update && apt install -y php8.2-fpm php8.2-common php8.2-mysql php8.2-cli php8.2-opcache php8.2-phpdbg php8.2-gd php-memcache php8.2-readline php8.2-zip php-json/bookworm python3-mysqldb/stable


apt purge -y postfix

cat > /etc/mysql/conf.d/mailpiler.conf <<EOF
innodb_buffer_pool_size=256M
innodb_flush_log_at_trx_commit=1
innodb_log_buffer_size=64M
innodb_log_file_size=16M
query_cache_size=0
query_cache_type=0
query_cache_limit=2M
EOF

systemctl restart mariadb

wget https://repo.manticoresearch.com/manticore-repo.noarch.deb
dpkg -i manticore-repo.noarch.deb
apt update

apt install manticore manticore-extra

systemctl start manticore
systemctl stop manticore
systemctl disable manticore

cd /tmp

wget https://bitbucket.org/jsuto/piler/downloads/xlhtml-0.5.1-sj-mod.tar.gz
gzip -dc xlhtml-0.5.1-sj-mod.tar.gz | tar -xvf -
cd xlhtml-0.5.1-sj-mod
./configure
make install

groupadd piler
useradd -g piler -m -s /bin/bash -d /var/piler piler
usermod -L piler
chmod 755 /var/piler

cd /tmp
https://bitbucket.org/jsuto/piler/downloads/piler-1.4.4.tar.gz
wget https://bitbucket.org/jsuto/piler/downloads/piler-$PILER_VERSION.tar.gz
tar -xvzf piler-$PILER_VERSION.tar.gz
cd piler-$PILER_VERSION/
./configure --localstatedir=/var --with-database=mysql --enable-memcached
make
make install
ldconfig

cp util/postinstall.sh util/postinstall.sh.bak
sed -i "s/   SMARTHOST=.*/   SMARTHOST="\"$SMARTHOST\""/" util/postinstall.sh
sed -i 's/   WWWGROUP=.*/   WWWGROUP="www-data"/' util/postinstall.sh

touch /usr/local/etc/piler/MANTICORE



make postinstall

# Edit on this page previus
echo "https://www.mailpiler.org/wiki/current:manticore"
# Cuidado al editar  /usr/local/etc/piler/piler.conf muchos valores estan duplicados....
pause

cp /usr/local/etc/piler/piler.conf /usr/local/etc/piler/piler.conf.bak
sed -i "s/hostid=.*/hostid=$PILER_DOMAIN/" /usr/local/etc/piler/piler.conf
sed -i "s/update_counters_to_memcached=.*/update_counters_to_memcached=1/" /usr/local/etc/piler/piler.conf

/etc/init.d/rc.piler start
/etc/init.d/rc.searchd start

update-rc.d rc.piler defaults
update-rc.d rc.searchd defaults

apt install -y apache2/stable
apt install -y certbot/stable

apt install python3-certbot-apache/stable

certbot --apache

a2enmod proxy_fcgi setenvif
a2enconf php8.2-fpm
systemctl restart apache2

# Edit crontab for the user piler

### PILERSTART
#5,35 * * * * /usr/local/libexec/piler/indexer.delta.sh
#30   2 * * * /usr/local/libexec/piler/indexer.main.sh
40 3 * * * /usr/local/libexec/piler/purge.sh
#3 * * * * /usr/local/libexec/piler/watch_sphinx_main_index.sh
#*/15 * * * * /usr/bin/indexer --quiet tag1 --rotate --config /usr/local/etc/piler/manticore.conf
#*/15 * * * * /usr/bin/indexer --quiet note1 --rotate --config /usr/local/etc/piler/manticore.conf
30   6 * * * /usr/bin/php /usr/local/libexec/piler/generate_stats.php --webui /var/piler/www >/dev/null
*/5 * * * * /usr/bin/find /var/piler/error -type f|wc -l > /var/piler/stat/error
*/5 * * * * /usr/bin/find /var/piler/www/tmp -type f -name i.\* -exec rm -f {} \;
#*/5 * * * * /usr/local/libexec/piler/import.sh
### PILEREND

The index is not needed if you use real time index


@ make you own config here...

cp /usr/local/etc/piler/config-site.php /usr/local/etc/piler/config-site.php.bak
sed -i "s|\$config\['SITE_URL'\] = .*|\$config\['SITE_URL'\] = 'https://$PILER_DOMAIN/';|" /usr/local/etc/piler/config-site.php
cat >> /usr/local/etc/piler/config-site.php <<EOF
// CUSTOM
\$config['PROVIDED_BY'] = '$PILER_DOMAIN';
\$config['SUPPORT_LINK'] = 'https://$PILER_DOMAIN';
\$config['COMPATIBILITY'] = '';
// fancy features.
\$config['ENABLE_INSTANT_SEARCH'] = 1;
\$config['ENABLE_TABLE_RESIZE'] = 1;
\$config['ENABLE_DELETE'] = 1;
\$config['ENABLE_ON_THE_FLY_VERIFICATION'] = 1;
// general settings.
\$config['TIMEZONE'] = 'Europe/Berlin';
// authentication
// Enable authentication against an imap server
//\$config['ENABLE_IMAP_AUTH'] = 1;
//\$config['RESTORE_OVER_IMAP'] = 1;
//\$config['IMAP_RESTORE_FOLDER_INBOX'] = 'INBOX';
//\$config['IMAP_RESTORE_FOLDER_SENT'] = 'Sent';
//\$config['IMAP_HOST'] = '$SMARTHOST';
//\$config['IMAP_PORT'] =  993;
//\$config['IMAP_SSL'] = true;
// authentication against an ldap directory (disabled by default)
//\$config['ENABLE_LDAP_AUTH'] = 1;
//\$config['LDAP_HOST'] = '$SMARTHOST';
//\$config['LDAP_PORT'] = 389;
//\$config['LDAP_HELPER_DN'] = 'cn=administrator,cn=users,dc=mydomain,dc=local';
//\$config['LDAP_HELPER_PASSWORD'] = 'myxxxxpasswd';
//\$config['LDAP_MAIL_ATTR'] = 'mail';
//\$config['LDAP_AUDITOR_MEMBER_DN'] = '';
//\$config['LDAP_ADMIN_MEMBER_DN'] = '';
//\$config['LDAP_BASE_DN'] = 'ou=Benutzer,dc=krs,dc=local';
// authentication against an Uninvention based ldap directory 
//\$config['ENABLE_LDAP_AUTH'] = 1;
//\$config['LDAP_HOST'] = '$SMARTHOST';
//\$config['LDAP_PORT'] = 7389;
//\$config['LDAP_HELPER_DN'] = 'uid=ldap-search-user,cn=users,dc=mydomain,dc=local';
//\$config['LDAP_HELPER_PASSWORD'] = 'myxxxxpasswd';
//\$config['LDAP_AUDITOR_MEMBER_DN'] = '';
//\$config['LDAP_ADMIN_MEMBER_DN'] = '';
//\$config['LDAP_BASE_DN'] = 'cn=users,dc=mydomain,dc=local';
//\$config['LDAP_MAIL_ATTR'] = 'mailPrimaryAddress';
//\$config['LDAP_ACCOUNT_OBJECTCLASS'] = 'person';
//\$config['LDAP_DISTRIBUTIONLIST_OBJECTCLASS'] = 'person';
//\$config['LDAP_DISTRIBUTIONLIST_ATTR'] = 'mailAlternativeAddress';
// special settings.
\$config['MEMCACHED_ENABLED'] = 1;
\$config['SPHINX_STRIC_T_SCHEMA'] = 1; // required for Sphinx $SPHINX_VERSION, see https://bitbucket.org/jsuto/piler/issues/1085/sphinx-331.
EOF



apt autoremove -y
apt clean -y
