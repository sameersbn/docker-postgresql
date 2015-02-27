# Table of Contents

- [Introduction](#introduction)
- [Changelog](Changelog.md)
- [Contributing](#contributing)
- [Reporting Issues](#reporting-issues)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Creating User and Database at Launch](creating-user-and-database-at-launch)
- [Configuration](#configuration)
    - [Data Store](#data-store)
    - [Securing the server](#securing-the-server)
- [Shell Access](#shell-access)
- [Upgrading](#upgrading)

# Introduction

Dockerfile to build a PostgreSQL container image which can be linked to other containers.

# Contributing

If you find this image useful here's how you can help:

- Send a Pull Request with your awesome new features and bug fixes
- Help new users with [Issues](https://github.com/sameersbn/docker-postgresql/issues) they may encounter
- Send me a tip via [Bitcoin](https://www.coinbase.com/sameersbn) or using [Gratipay](https://gratipay.com/sameersbn/)

# Reporting Issues

Docker is a relatively new project and is active being developed and tested by a thriving community of developers and testers and every release of docker features many enhancements and bugfixes.

Given the nature of the development and release cycle it is very important that you have the latest version of docker installed because any issue that you encounter might have already been fixed with a newer docker release.

For ubuntu users I suggest [installing docker](https://docs.docker.com/installation/ubuntulinux/) using docker's own package repository since the version of docker packaged in the ubuntu repositories are a little dated.

Here is the shortform of the installation of an updated version of docker on ubuntu.

```bash
sudo apt-get purge docker.io
curl -s https://get.docker.io/ubuntu/ | sudo sh
sudo apt-get update
sudo apt-get install lxc-docker
```

Fedora and RHEL/CentOS users should try disabling selinux with `setenforce 0` and check if resolves the issue. If it does than there is not much that I can help you with. You can either stick with selinux disabled (not recommended by redhat) or switch to using ubuntu.

If using the latest docker version and/or disabling selinux does not fix the issue then please file a issue request on the [issues](https://github.com/sameersbn/docker-postgresql/issues) page.

In your issue report please make sure you provide the following information:

- The host ditribution and release version.
- Output of the `docker version` command
- Output of the `docker info` command
- The `docker run` command you used to run the image (mask out the sensitive bits).

# Installation

Pull the latest version of the image from the docker index. This is the recommended method of installation as it is easier to update image in the future. These builds are performed by the **Docker Trusted Build** service.

```bash
docker pull sameersbn/postgresql:9.4
```

Alternately you can build the image yourself.

```bash
git clone https://github.com/sameersbn/docker-postgresql.git
cd docker-postgresql
docker build -t="$USER/postgresql" .
```

# Quick Start

Run the postgresql image

```bash
docker run --name postgresql -d sameersbn/postgresql:9.4
```

The simplest way to login to the postgresql container as the administrative `postgres` user is to use the `--volumes-from` docker option to connect to the postgresql server over the unix socket.

```bash
docker run -it --rm --volumes-from=postgresql \
  sameersbn/postgresql:9.4 sudo -u postgres -H psql
```

Alternately you can fetch the password set for the `postgres` user from the container logs.

```bash
docker logs postgresql
```

In the output you will notice the following lines with the password:

```bash
|------------------------------------------------------------------|
| PostgreSQL User: postgres, Password: xxxxxxxxxxxxxx              |
|                                                                  |
| To remove the PostgreSQL login credentials from the logs, please |
| make a note of password and then delete the file pwfile          |
| from the data store.                                             |
|------------------------------------------------------------------|
```

To test if the postgresql server is working properly, try connecting to the server.

```bash
psql -U postgres -h $(docker inspect --format {{.NetworkSettings.IPAddress}} postgresql)
```

# Creating User and Database at Launch

The image allows you to create a user and database at launch time.

To create a new user you should specify the `DB_USER` and `DB_PASS` variables. The following command will create a new user *dbuser* with the password *dbpass*.

```bash
docker run --name postgresql -d \
  -e 'DB_USER=dbuser' -e 'DB_PASS=dbpass' \
  sameersbn/postgresql:9.4
```

**NOTE**
- If the password is not specified the user will not be created
- If the user user already exists no changes will be made

Similarly, you can also create a new database by specifying the database name in the `DB_NAME` variable.

```bash
docker run --name postgresql -d \
  -e 'DB_NAME=dbname' sameersbn/postgresql:9.4
```

You may also specify a comma separated list of database names in the `DB_NAME` variable. The following command creates two new databases named *dbname1* and *dbname2 (p.s. this feature is only available in releases greater than 9.4)*

```bash
docker run --name postgresql -d \
-e 'DB_NAME=dbname1,dbname2' sameersbn/postgresql:latest
```

If the `DB_USER` and `DB_PASS` variables are also specified while creating the database, then the user is granted access to the database(s).

For example,

```bash
docker run --name postgresql -d \
  -e 'DB_USER=dbuser' -e 'DB_PASS=dbpass' -e 'DB_NAME=dbname' \
  sameersbn/postgresql:9.4
```

, will create a user *dbuser* with the password *dbpass*. It will also create a database named *dbname* and the *dbuser* user will have full access to the *dbname* database.

The `PSQL_TRUST_LOCALNET` environment variable can be used to configure postgres to trust connections on the same network.  This is handy for other containers to connect without authentication. To enable this behavior, set `PSQL_TRUST_LOCALNET` to `true`.

For example,

```bash
docker run --name postgresql -d \
  -e 'PSQL_TRUST_LOCALNET=true' \
  sameersbn/postgresql:9.4
```

This has the effect of adding the following to the `pg_hba.conf` file:

```
host    all             all             samenet                 trust
```

# Configuration

## Data Store

For data persistence a volume should be mounted at `/var/lib/postgresql`.

SELinux users are also required to change the security context of the mount point so that it plays nicely with selinux.

```bash
mkdir -p /opt/postgresql/data
sudo chcon -Rt svirt_sandbox_file_t /opt/postgresql/data
```

The updated run command looks like this.

```bash
docker run --name postgresql -d \
  -v /opt/postgresql/data:/var/lib/postgresql sameersbn/postgresql:9.4
```

This will make sure that the data stored in the database is not lost when the image is stopped and started again.

## Enable Unaccent (Search plain text with accent)

Unaccent is a text search dictionary that removes accents (diacritic signs) from lexemes. It's a filtering dictionary, which means its output is always passed to the next dictionary (if any), unlike the normal behavior of dictionaries. This allows accent-insensitive processing for full text search.

By default unaccent is configure to `false`

```bash
docker run --name postgresql -d \
  -e 'DB_UNACCENT=true' \
  sameersbn/postgresql:9.4
```

## Securing the server

By default a randomly generated password is assigned for the postgres user. The password is stored in a file named `pwfile` in the data store and is printed in the logs.

If you dont want this password to be displayed in the logs, then please note down the password listed in `/opt/postgresql/data/pwfile` and then delete the file.

```bash
cat /opt/postgresql/data/pwfile
rm /opt/postgresql/data/pwfile
```

Alternately, you can change the password of the postgres user

```bash
psql -U postgres -h $(docker inspect --format {{.NetworkSettings.IPAddress}} postgresql)
\password postgres
```

# Shell Access

For debugging and maintenance purposes you may want access the containers shell. If you are using docker version `1.3.0` or higher you can access a running containers shell using `docker exec` command.

```bash
docker exec -it postgresql bash
```

If you are using an older version of docker, you can use the [nsenter](http://man7.org/linux/man-pages/man1/nsenter.1.html) linux tool (part of the util-linux package) to access the container shell.

Some linux distros (e.g. ubuntu) use older versions of the util-linux which do not include the `nsenter` tool. To get around this @jpetazzo has created a nice docker image that allows you to install the `nsenter` utility and a helper script named `docker-enter` on these distros.

To install `nsenter` execute the following command on your host,

```bash
docker run --rm -v /usr/local/bin:/target jpetazzo/nsenter
```

Now you can access the container shell using the command

```bash
sudo docker-enter postgresql
```

For more information refer https://github.com/jpetazzo/nsenter

# Upgrading

To upgrade to newer releases, simply follow this 3 step upgrade procedure.

- **Step 1**: Stop the currently running image

```bash
docker stop postgresql
```

- **Step 2**: Update the docker image.

```bash
docker pull sameersbn/postgresql:9.4
```

- **Step 3**: Start the image

```bash
docker run --name postgresql -d [OPTIONS] sameersbn/postgresql:9.4
```
