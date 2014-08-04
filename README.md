# Table of Contents
- [Introduction](#introduction)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
    - [Data Store](#data-store)
    - [Securing the server](#securing-the-server)
- [Upgrading](#upgrading)
- [Issues](#issues)

# Introduction
Dockerfile to build a PostgreSQL container image which can be linked to other containers.

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
docker run -name postgresql -d sameersbn/postgresql:latest
POSTGRESQL_IP=$(docker inspect --format {{.NetworkSettings.IPAddress}} postgresql)
```

By default remote logins are permitted to the postgresql server and a random password is assigned for the postgres user. The password set for the postgres user can be retrieved from the container logs.

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
psql -U postgres -h ${POSTGRESQL_IP}
```

# Configuration

## Data Store
For data persistence a volume should be mounted at /var/lib/postgresql.

```bash
mkdir /opt/postgresql/data
docker run -name postgresql -d \
  -v /opt/postgresql/data:/var/lib/postgresql sameersbn/postgresql:latest
```

This will make sure that the data stored in the database is not lost when the image is stopped and started again.

## Securing the server
By default a randomly generated password is assigned for the postgres user. The password is stored in a file named pwpass in the data store and is printed in the logs.

If you dont want this password to be displayed in the logs, then please note down the password listed in /opt/postgresql/data/pwpass and then delete the file.

```bash
cat /opt/postgresql/data/pwfile
rm /opt/postgresql/data/pwfile
```

Alternately, you can change the password of the postgres user

```bash
psql -U postgres -h ${POSTGRESQL_IP}
\password postgres
```

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
docker run -name postgresql -d [OPTIONS] sameersbn/postgresql:latest
```

# Issues
Please report issues [here](https://github.com/sameersbn/docker-postgresql/issues)
