#!/bin/bash
# This is a helper script. DO NOT RUN MANUALLY. It is NOT executable for a reason!
set -e
die() {
    echo "$1"
    exit 99
}
[ -n "$2" ] || die "Not enough arguments - DO NOT RUN MANUALLY! This is used inside the container."

PLUGIN="$1"
PLUGIN_VERSION="$2"
PLUGIN_URL="$3"
echo "Installing Trac plugin ${PLUGIN} version ${PLUGIN_VERSION}"
if [ -n "${PLUGIN_URL}" ]; then
    echo "Using forced URL: ${PLUGIN_URL}"
else
    PLUGIN_URL="https://trac-hacks.org/browser/${PLUGIN}/${PLUGIN_VERSION}?format=zip"
    echo "Using generated URL: ${PLUGIN_URL}"
fi

mkdir /workspace-${PLUGIN}
cd /workspace-${PLUGIN}
wget -O ./${PLUGIN}.zip "${PLUGIN_URL}"
unzip ./${PLUGIN}.zip
cd $(basename ${PLUGIN_VERSION})
# This is extremely poorly tested and currently unused. Don't.
if [ x"${RPMNEEDED}" == x1 ]; then
    python2 ./setup.py bdist_rpm
    mv -v dist/*noarch.rpm /workspace/RPMs/
else
    python2 ./setup.py bdist_egg
    mv -v dist/*.egg /workspace/RPMs/
fi
