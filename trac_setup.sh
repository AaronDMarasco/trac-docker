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
cp -v /container_info/*.egg ${TRAC_DIR}/plugins/
# Upgrade everything with plugins installed
trac-admin "${TRAC_DIR}" upgrade --no-backup
trac-admin "${TRAC_DIR}" wiki upgrade
trac-admin ${TRAC_DIR} deploy ${TRAC_DIR}/www/
trac-admin ${TRAC_DIR} permission add "${TRAC_ADMIN_NAME}" TRAC_ADMIN
htpasswd -b -c ${TRAC_DIR}/www/.htpasswd "${TRAC_ADMIN_NAME}" "${TRAC_ADMIN_PASSWD}"
chown -R apache:apache ${TRAC_DIR}
# SELinux permissions
# dnf install -y policycoreutils-python-utils
# semanage fcontext -a -t httpd_sys_content_t "${TRAC_DIR}(/.*)?"
# restorecon -Rv ${TRAC_DIR}

sed -e "s|@AUTH_NAME@|${TRAC_PROJECT_NAME}|g" -e "s|@TRAC_DIR@|${TRAC_DIR}|g" < trac.conf > /etc/httpd/conf.d/trac.conf
### Custom plugin configuration
### Note: Trac will merge multiple sections of the same name, so you can feel free to duplicate "components"
### Note: Plugins are automatically enabled; ONLY add here if there is non-default configuration
cat <<EOF >>${TRAC_DIR}/conf/trac.ini
; Out-of-the-box we will have email disabled by default
[components]
trac.notification.mail.emaildistributor = disabled

; PLUGIN: PrivateTicketsPlugin
[components]
privatetickets.policy.privateticketspolicy = enabled

[privatetickets]
group_blacklist = anonymous,authenticated

; PLUGIN: TracIniAdminPanelPlugin
; We will allow admin user to remotely modify the entire INI file by default
[ini-editor-restrictions]
default-access = modifiable

; DISABLED PLUGIN: TracFullBlog
[components]
tracfullblog.* = disabled
EOF
# Upgrade everything with plugins configured
trac-admin "${TRAC_DIR}" upgrade --no-backup
httpd -M | grep wsgi
httpd -t
httpd -S
