# trac-docker

[![](https://images.microbadger.com/badges/version/admarasco/trac.svg)](https://microbadger.com/images/admarasco/trac "Get your own version badge on microbadger.com")
[![](https://images.microbadger.com/badges/image/admarasco/trac.svg)](https://microbadger.com/images/admarasco/trac "Get your own image badge on microbadger.com")
[![Docker Hub](http://img.shields.io/docker/pulls/admarasco/trac.svg)](https://hub.docker.com/r/admarasco/trac/)

This repo is used to host a bundle to create a container based on Red Hat's [UBI](https://developers.redhat.com/products/rhel/ubi/) running [Trac](http://trac.edgewall.org),
which is an enhanced wiki and issue tracking system for software development projects.

Trac uses a minimalistic approach to web-based software project management. It helps developers write great software while staying out of the way. Trac should impose as little as possible on a team's established development process and policies.

The author of this bundle has been using Trac on and off for about fifteen years (since around 2006 in the Trac 0.9 days).

# How to get the image

* Build it using `Dockerfile`

    ```ssh
    $ git clone https://github.com/aarondmarasco/trac-docker
    $ cd trac-docker
    $ podman build -t trac ./
    ```

* Just pull it from Docker hub

    ```
    $ podman pull docker://docker.io/admarasco/trac
    ```


# How to run the container

## Quick Start

Just run

```
$ podman run -d -p 8123:8123 --name my_trac admarasco/trac
```

After several seconds, you can visit the web page at
<http://localhost:8123>

## Image Build-Time Arguments

* `TRAC_ADMIN_NAME` (default is `trac_admin`):

    the admin username of Trac

* `TRAC_ADMIN_PASSWD` (default is `passw0rd`):

    the admin password of Trac

* `TRAC_PROJECT_NAME` (default is `trac_project`):

    the Trac project name

* `TRAC_DIR` (default is `/var/local/trac`):

    This directory stores all the data and configurations. You can bind a volume
    when starting a container.

* `TRAC_INI` (default is `$TRAC_DIR/conf/trac.ini`):

    This ini file will be automatically generated by the container.
    Also you can make some customizations based on your needs.
    (This guide assumes you know how to copy out.)

* `DB_LINK` (default is `sqlite:db/trac.db`):

    A database system is needed. The database can be one of: `SQLite`, `PostgreSQL` or `MySQL`.

    Please refer <https://trac.edgewall.org/wiki/TracInstall#MandatoryDependencies> for more detailed infomation.

    * For the PostgreSQL database

        See [DatabaseBackend](https://trac.edgewall.org/wiki/DatabaseBackend#PostgreSQL) for details.

    * For the MySQL database

        Trac works well with MySQL.
        Given the caveats and known issues surrounding MySQL,
        read the [MySqlDb](https://trac.edgewall.org/intertrac/MySqlDb) page
        before creating the database.


## Misc Security

This container image is powered by [Apache Web Server](https://httpd.apache.org/).

You can make your own customizations (such as adding TLS, etc.) in `./trac.conf` and map to `/etc/apache2/sites-available/trac.conf` when starting a container.

```
$ podman run -d -p 8123:8123 -v ./trac.conf:/etc/apache2/sites-available/trac.conf --name my_trac admarasco/trac
```

# Reference

* [Trac Official Doc](https://trac.edgewall.org/wiki/TracGuide)
