# Table of Contents

- [Introduction](#introduction)
- [Changelog](Changelog.md)
- [Reporting Issues](#reporting-issues)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
    - [Data Store](#data-store)
    - [Securing the server](#securing-the-server)
- [Shell Access](#shell-access)
- [Upgrading](#upgrading)

# Introduction

Dockerfile to build a PostgreSQL container image which can be linked to other containers.

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
docker pull sameersbn/postgresql:latest
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
docker run --name postgresql -d sameersbn/postgresql:latest
```

By default remote logins are permitted to the postgresql server and a random password is assigned for the postgres user. The password set for the `postgres` user can be retrieved from the container logs.

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
  -v /opt/postgresql/data:/var/lib/postgresql sameersbn/postgresql:latest
```

This will make sure that the data stored in the database is not lost when the image is stopped and started again.

## Securing the server

By default a randomly generated password is assigned for the postgres user. The password is stored in a file named `pwpass` in the data store and is printed in the logs.

If you dont want this password to be displayed in the logs, then please note down the password listed in `/opt/postgresql/data/pwpass` and then delete the file.

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

For debugging and maintenance purposes you may want access the container shell. Since the container does not allow interactive login over the SSH protocol, you can use the [nsenter](http://man7.org/linux/man-pages/man1/nsenter.1.html) linux tool (part of the util-linux package) to access the container shell.

Some linux distros (e.g. ubuntu) use older versions of the util-linux which do not include the `nsenter` tool. To get around this @jpetazzo has created a nice docker image that allows you to install the `nsenter` utility and a helper script named `docker-enter` on these distros.

To install the nsenter tool on your host execute the following command.

```bash
docker run --rm -v /usr/local/bin:/target jpetazzo/nsenter
```

Now you can access the container shell using the command

```bash
sudo docker-enter postgresql
```

For more information refer https://github.com/jpetazzo/nsenter

Another tool named `nsinit` can also be used for the same purpose. Please refer https://jpetazzo.github.io/2014/03/23/lxc-attach-nsinit-nsenter-docker-0-9/ for more information.

# Upgrading

To upgrade to newer releases, simply follow this 3 step upgrade procedure.

- **Step 1**: Stop the currently running image

```bash
docker stop postgresql
```

- **Step 2**: Update the docker image.

```bash
docker pull sameersbn/postgresql:latest
```

- **Step 3**: Start the image

```bash
docker run --name postgresql -d [OPTIONS] sameersbn/postgresql:latest
```
