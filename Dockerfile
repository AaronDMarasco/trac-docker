# I guess we're screwed May 2021...
# Eventually, when trac moves to py3, we'll move (back) to UBI
FROM fedora:31 AS builder

RUN mkdir -p /workspace/RPMs
WORKDIR /workspace

# Normally, you don't do dnf on multiple lines when building a container, but this will be thrown away.

RUN dnf upgrade -v -y --refresh

# I have existing trac installations at 1.4, and F31 is only 1.2, so rebuild it
ARG TRAC_RPM_SRC=trac-1.4-2.fc32.src.rpm
ARG TRAC_RPM_SRC_URL=https://download.fedoraproject.org/pub/fedora/linux/releases/32/Everything/source/tree/Packages/t/${TRAC_RPM_SRC}

ADD ${TRAC_RPM_SRC_URL} /workspace/

WORKDIR /workspace/
RUN useradd mock
RUN dnf install -y rpm-build python2-devel python2-jinja2 python2-genshi python2-setuptools wget
RUN rpmbuild --rebuild ${TRAC_RPM_SRC}
RUN cp -v --target-directory=/workspace/RPMs /root/rpmbuild/RPMS/noarch/trac-*rpm

# From what I understand, we could loop nicer with buildah, but want to be compat w/ docker we ensure this Dockerfile is the entry point (if we did a build.sh or something, then DockerHub wouldn't auto-build)
COPY plugin_builder.sh /workspace/
RUN chmod a+x /workspace/plugin_builder.sh

### This is where you add more plugins to the base image ###
# You need to check if the URL has "tags" or not and set appropriately
# It will download https://trac-hacks.org/browser/${PLUGIN}/${PLUGIN_VERSION}?format=zip
# unless you give it a third argument, a double-quoted ZIP source URL (cannot just use "trunk")
RUN /workspace/plugin_builder.sh accountmanagerplugin trunk "https://trac-hacks.org/browser/accountmanagerplugin/trunk?rev=17755&format=zip"
RUN /workspace/plugin_builder.sh addheadersplugin 0.12
RUN /workspace/plugin_builder.sh advparseargsplugin 0.11
RUN /workspace/plugin_builder.sh changelogmacro trunk "https://trac-hacks.org/browser/changelogmacro/trunk?rev=17738&format=zip"
RUN /workspace/plugin_builder.sh fullblogplugin 1.4
RUN /workspace/plugin_builder.sh onsitenotificationsplugin trunk "https://trac-hacks.org/browser/onsitenotificationsplugin/trunk?rev=17740&format=zip"
RUN /workspace/plugin_builder.sh privateticketsplugin tags/2.3.0
RUN /workspace/plugin_builder.sh tagsplugin trunk "https://trac-hacks.org/browser/tagsplugin/trunk?rev=17752&format=zip"
RUN /workspace/plugin_builder.sh traciniadminpanelplugin trunk "https://trac-hacks.org/browser/traciniadminpanelplugin/trunk?rev=17740&format=zip"
RUN /workspace/plugin_builder.sh weekplanplugin tags/weekplan-1.3
RUN /workspace/plugin_builder.sh wikiautocompleteplugin trunk "https://trac-hacks.org/browser/wikiautocompleteplugin/trunk?rev=17740&format=zip"
RUN /workspace/plugin_builder.sh wikiextrasplugin tags/1.3.1

RUN rm -rf /workspace/RPMs/*debuginfo*

# Now we build the actual image we are distributing so minimize layers
FROM fedora:31
LABEL maintainer="Aaron D. Marasco <trac-docker@marascos.net>"
# User can expose anything they want and override with "-p" option
EXPOSE 8123

WORKDIR /container_info
COPY --from=builder /workspace/RPMs/*.rpm /workspace/RPMs/*.egg /container_info/

# This brings in the helper script (to minimize layers) as well as leaves behind the configuration info
COPY Dockerfile trac_setup.sh trac.conf /container_info/

RUN dnf upgrade -v -y --refresh && \
    dnf install -y /container_info/*.rpm mod_wsgi libserf subversion subversion-python subversion-tools mod_dav_svn && \
    dnf clean all && \
    rm -rf /usr/share/doc /usr/share/info /usr/share/man /var/cache/dnf

# All ARGS reset at FROM so can't be at the top
ARG TRAC_ADMIN_NAME=trac_admin
ARG TRAC_ADMIN_PASSWD=passw0rd
ARG TRAC_PROJECT_NAME=trac_project
ARG TRAC_DIR=/srv/trac
ARG TRAC_INI="${TRAC_DIR}/conf/trac.ini"
ARG DB_LINK=sqlite:db/trac.db

RUN chmod a+x trac_setup.sh && ./trac_setup.sh "${TRAC_ADMIN_NAME}" "${TRAC_ADMIN_PASSWD}" "${TRAC_PROJECT_NAME}" "${TRAC_DIR}" "${TRAC_INI}" "${DB_LINK}"

CMD ["-D", "FOREGROUND"]
ENTRYPOINT ["/usr/sbin/httpd"]
