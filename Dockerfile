FROM centos:8 AS builder
MAINTAINER = Aaron D. Marasco <trac-ubi@marascos.net>
EXPOSE 8123

RUN mkdir -p /workspace/RPMs
WORKDIR /workspace

# Normally, you don't do dnf on multiple lines when building a container, but this will
# be thrown away.
# RUN sed -i 's/enabled=0/enabled=1/' /etc/yum.repos.d/CentOS-PowerTools.repo

# This is to fix problems I had on DockerHub that I thought were fixed pre-DNF days...
# RUN touch /var/lib/rpm/* && dnf install --disablerepo '*' -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
# RUN touch /var/lib/rpm/* && dnf install --disablerepo '*' --enablerepo 'epel' -y dnf-plugin-ovl

# TEMPORARY! I fixed overlay detection and until that change propagates to EPEL, the above won't work.
ADD https://raw.githubusercontent.com/AaronDMarasco/dnf-plugin-ovl/master/ovl.py /usr/lib/python3.6/site-packages/dnf-plugins/

RUN dnf upgrade -v -y --refresh
# I think the genshi specfile is broken - it shouldn't need python3 devel to build python2, but this is easier than fixing it...
RUN dnf install -y rpm-build python2-devel python2-jinja2 gcc httpd-devel make python3-devel python3-setuptools wget

# This is ugly... but it works for now...
# Maybe need to have a helper script that downloads later for local cache?

# As of 7-May-20, CentOS/UBI doesn't have python2 mod_wsgi nor genshi, which are prereqs for trac.
# So we need to build them (and install genshi) before we can build trac itself.
# TODO: Figure out how trac works in Fedora 32? Where do they get mod_wsgi, etc?
ARG MOD_WSGI_SRC=mod_wsgi-4.6.8-2.fc32.src.rpm
ARG MOD_WSGI_SRC_URL=https://download.fedoraproject.org/pub/fedora/linux/releases/32/Everything/source/tree/Packages/m/${MOD_WSGI_SRC}
ARG GENSHI_SRC=python-genshi-0.7.3-5.fc32.src.rpm
ARG GENSHI_SRC_URL=https://mirror.clarkson.edu/fedora/linux/releases/32/Everything/source/tree/Packages/p/${GENSHI_SRC}
ARG TRAC_RPM_SRC=trac-1.4-2.fc32.src.rpm
ARG TRAC_RPM_SRC_URL=https://download.fedoraproject.org/pub/fedora/linux/releases/32/Everything/source/tree/Packages/t/${TRAC_RPM_SRC}

ADD ${GENSHI_SRC_URL} ${MOD_WSGI_SRC_URL} ${TRAC_RPM_SRC_URL} /workspace/

RUN rpmbuild --rebuild ${GENSHI_SRC}
RUN dnf install -y ~/rpmbuild/RPMS/x86_64/python2-genshi-*rpm

# The mod_wsgi package needs to have the specfile edited; it forces with_python2 and 3 based on OS versions with no way to override...
RUN mkdir wsgi
WORKDIR /workspace/wsgi
RUN rpm2cpio ../${MOD_WSGI_SRC} | cpio -div
RUN sed -i.bak -e '9,21d' *.spec
# Sanity check - should only show stuff concerning python versions (uncomment if changing versions)
# RUN diff -u *spec*
RUN mv -v --target-directory=/root/rpmbuild/SOURCES *.patch *.tar.gz *.conf
RUN rpmbuild -ba -D "with_python2 1" -D "with_python3 0" *.spec

WORKDIR /workspace/
RUN rpmbuild --rebuild ${TRAC_RPM_SRC}
RUN cp -v --target-directory=/workspace/RPMs /root/rpmbuild/RPMS/{noarch/trac-,x86_64/python2-}*rpm

# There is no "default" python since python3 not installed. Stomping on system python temporarily
RUN ln -s /usr/bin/python2 /usr/bin/python
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

## This is the previous way, which was error-prone because svn loves to timeout and crash
## Kept here in case ever needed to bring back (would lose in squashed merge)
# ARG PLUGIN=addheadersplugin
# ARG PLUGIN_VERSION=0.12
# WORKDIR /workspace-${PLUGIN}
# RUN svn co https://trac-hacks.org/svn/${PLUGIN}/${PLUGIN_VERSION} src
# WORKDIR /workspace-${PLUGIN}/src
# RUN python2 ./setup.py bdist_rpm
# RUN mv -v dist/*noarch.rpm /workspace/RPMs/
# ## End of plugin

RUN rm -rf /workspace/RPMs/*debuginfo*

# Now we build the actual image we are distributing
FROM registry.access.redhat.com/ubi8/ubi:latest
# TODO - What is the offical UBI answer?
# ADD https://raw.githubusercontent.com/AaronDMarasco/dnf-plugin-ovl/master/ovl.py /usr/lib/python3.6/site-packages/dnf-plugins/
WORKDIR /container_info
COPY --from=builder /workspace/RPMs/*.rpm /workspace/RPMs/*.egg /container_info/
# RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
# UBI's AppStream is very limited, so we need to pull subversion/mod_dav_svn from WANdisco's distribution (CentOS 8 AppStream doesn't include subversion-python)
RUN printf '[c8-appstream]\nname=CentOS 8 AppStream\nbaseurl = http://mirror.centos.org/centos/8-stream/AppStream/$basearch/os/\nenabled = 0\ngpgcheck = 0\n\n[wandisco-svn]\nname=WANdisco Subversion\nbaseurl = http://opensource.wandisco.com/centos/8/svn-1.9/RPMS/$basearch/\nenabled = 0\ngpgcheck = 0' > /etc/yum.repos.d/extra_repos.repo

RUN dnf remove -y --disableplugin subscription-manager {dnf-plugin-,}subscription-manager && \
    dnf install -y -v httpd python36 /container_info/*.rpm && \
    dnf install -y --disablerepo '*' --enablerepo wandisco-svn libserf subversion subversion-python subversion-tools mod_dav_svn && \
    dnf clean all && \
    rm -rf /usr/share/{doc,info,man} && \
    rm -rf /var/cache/dnf

# All ARGS reset at FROM so can't be at the top
ARG TRAC_ADMIN_NAME=trac_admin
ARG TRAC_ADMIN_PASSWD=passw0rd
ARG TRAC_PROJECT_NAME=trac_project
ARG TRAC_DIR=/srv/trac
ARG TRAC_INI="${TRAC_DIR}/conf/trac.ini"
ARG DB_LINK=sqlite:db/trac.db

# This brings in the helper script (to minimize layers) as well as leaves behind the configuration info
COPY Dockerfile trac_setup.sh trac.conf /container_info/

RUN chmod a+x trac_setup.sh && ./trac_setup.sh "${TRAC_ADMIN_NAME}" "${TRAC_ADMIN_PASSWD}" "${TRAC_PROJECT_NAME}" "${TRAC_DIR}" "${TRAC_INI}" "${DB_LINK}"

CMD ["-D", "FOREGROUND"]
ENTRYPOINT ["/usr/sbin/httpd"]
