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
printf "\nBuilding Trac plugin ${PLUGIN} (${PLUGIN_VERSION})\n"
if [ -n "${PLUGIN_URL}" ]; then
    true
    # echo "Using forced URL: ${PLUGIN_URL}"
else
    PLUGIN_URL="https://trac-hacks.org/browser/${PLUGIN}/${PLUGIN_VERSION}?format=zip"
    # echo "Using generated URL: ${PLUGIN_URL}"
fi

mkdir /workspace-${PLUGIN}
cd /workspace-${PLUGIN}
wget --no-verbose --output-document=./${PLUGIN}.zip "${PLUGIN_URL}"
unzip -q ./${PLUGIN}.zip
cd $(basename ${PLUGIN_VERSION})
echo "Logging build to /workspace/eggs/logs/${PLUGIN}.log"
python2 ./setup.py bdist_egg > /workspace/eggs/logs/${PLUGIN}.log 2>&1
mv -v dist/*.egg /workspace/eggs/
