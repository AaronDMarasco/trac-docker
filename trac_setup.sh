#!/bin/bash
# This is a helper script. DO NOT RUN MANUALLY. It is NOT executable for a reason!
set -e
die() {
    echo "$1"
    exit 99
}
[ -n "$6" ] || die "Not enough arguments - DO NOT RUN MANUALLY! This is used inside the container."

TRAC_ADMIN_NAME="$1"
TRAC_ADMIN_PASSWD="$2"
TRAC_PROJECT_NAME="$3"
TRAC_DIR="$4"
TRAC_INI="$5"
DB_LINK="$6"

echo "Setting up project ${TRAC_PROJECT_NAME} in ${TRAC_DIR}..."
set -x

mkdir -p ${TRAC_DIR}
trac-admin ${TRAC_DIR} initenv "${TRAC_PROJECT_NAME}" "${DB_LINK}"
trac-admin ${TRAC_DIR} deploy ${TRAC_DIR}/www/
trac-admin ${TRAC_DIR} permission add "${TRAC_ADMIN_NAME}" TRAC_ADMIN
htpasswd -b -c ${TRAC_DIR}/www/.htpasswd "${TRAC_ADMIN_NAME}" "${TRAC_ADMIN_PASSWD}"
chown -R apache:apache ${TRAC_DIR}
# FIXME SELinux permissions?
# mv trac.conf /etc/httpd/conf.d
sed -e "s|@AUTH_NAME@|${TRAC_PROJECT_NAME}|g" -e "s|@TRAC_DIR@|${TRAC_DIR}|g" < trac.conf > /etc/httpd/conf.d/trac.conf
# Enable the IniAdmin plugin
# /usr/libexec/platform-python -c 'import configparser; config = configparser.ConfigParser(); config.read("trac.ini"); config["components"]={"iniadmin.*":"enabled"}; f = open("trac2.ini", "w"); config.write(f)'
cat <<EOF >>${TRAC_DIR}/conf/trac.ini
[components]
iniadmin.* = enabled
EOF
# cd ${TRAC_DIR}/plugins/
# ln -s /usr/lib/python2.7/site-packages/iniadmin

httpd -M | grep wsgi
httpd -t
httpd -S
