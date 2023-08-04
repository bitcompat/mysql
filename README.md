# MySQL

## What is MySQL?

> MySQL is a fast, reliable, scalable, and easy to use open source relational database system. Designed to handle mission-critical, heavy-load production applications.

[Overview of MySQL](http://www.mysql.com)

Trademarks: The respective trademarks mentioned in the offering are owned by the respective companies, and use of them does not imply any affiliation or endorsement.

## TL;DR

```console
$ docker run --name mysql -e ALLOW_EMPTY_PASSWORD=yes ghcr.io/bitcompat/mysql:latest
```

**Warning**: These quick setups are only intended for development environments. You are encouraged to change the insecure default credentials and check out the available configuration options in the [Configuration](#configuration) section for a more secure deployment.

## Why use a non-root container?

Non-root container images add an extra layer of security and are generally recommended for production environments. However, because they run as a non-root user, privileged tasks are typically off-limits.

## Get this image

The recommended way to get the Bitcompat MySQL Docker Image is to pull the prebuilt image from the [Docker Hub Registry](https://hub.docker.com/r/bitnami/mysql).

```console
$ docker pull ghcr.io/bitcompat/mysql:latest
```

To use a specific version, you can pull a versioned tag. You can view the
[list of available versions](https://hub.docker.com/r/bitnami/mysql/tags/)
in the Docker Hub Registry.

```console
$ docker pull ghcr.io/bitcompat/mysql:[TAG]
```

## Persisting your database

If you remove the container all your data will be lost, and the next time you run the image the database will be reinitialized. To avoid this loss of data, you should mount a volume that will persist even after the container is removed.

For persistence, you should mount a directory at the `/bitnami/mysql/data` path. If the mounted directory is empty, it will be initialized on the first run.

```console
$ docker run \
    -e ALLOW_EMPTY_PASSWORD=yes \
    -v /path/to/mysql-persistence:/bitnami/mysql/data \
    ghcr.io/bitcompat/mysql:latest
```

> NOTE: As this is a non-root container, the mounted files and directories must have the proper permissions for the UID `1001`.

## Connecting to other containers

Using [Docker container networking](https://docs.docker.com/engine/userguide/networking/), a MySQL server running inside a container can easily be accessed by your application containers.

Containers attached to the same network can communicate with each other using the container name as the hostname.

### Using the Command Line

In this example, we will create a MySQL client instance that will connect to the server instance that is running on the same docker network as the client.

#### Step 1: Create a network

```console
$ docker network create app-tier --driver bridge
```

#### Step 2: Launch the MySQL server instance

Use the `--network app-tier` argument to the `docker run` command to attach the MySQL container to the `app-tier` network.

```console
$ docker run -d --name mysql-server \
    -e ALLOW_EMPTY_PASSWORD=yes \
    --network app-tier \
    ghcr.io/bitcompat/mysql:latest
```

#### Step 3: Launch your MySQL client instance

Finally, we create a new container instance to launch the MySQL client and connect to the server created in the previous step:

```console
$ docker run -it --rm \
    --network app-tier \
    ghcr.io/bitcompat/mysql:latest mysql -h mysql-server -u root
```

## Configuration

### Initializing a new instance

The container can execute custom files on the first start and on every start. Files with extensions `.sh`, `.sql` and `.sql.gz` are supported.

- Files in `/docker-entrypoint-initdb.d` will only execute on the first container start.
- Files in `/docker-entrypoint-startdb.d` will execute on every container start.

In order to have your custom files inside the docker image you can mount them as a volume.

Take into account those scripts are treated differently depending on the extension. While the `.sh` scripts are executed in all the nodes; the `.sql` and `.sql.gz` scripts are only executed in the master nodes. The reason behind this differentiation is that the `.sh` scripts allow adding conditions to determine what is the node running the script, while these conditions can't be set using `.sql` nor `sql.gz` files. This way it is possible to cover different use cases depending on their needs.

> NOTE: If you are importing large databases, it is recommended to import them as `.sql` instead of `.sql.gz`, as the latter one needs to be decompressed on the fly and not allowing for additional optimizations to import large files.

### Setting the root password on first run

The root user and password can easily be setup with the Bitnami MySQL Docker image using the following environment variables:

- `MYSQL_ROOT_USER`: The database admin user. Defaults to `root`.
- `MYSQL_ROOT_PASSWORD`: The database admin user password. No defaults.

Passing the `MYSQL_ROOT_PASSWORD` environment variable when running the image for the first time will set the password of the `MYSQL_ROOT_USER` user to the value of `MYSQL_ROOT_PASSWORD`.

```console
$ docker run --name mysql -e MYSQL_ROOT_PASSWORD=password123 bitnami/mysql:latest
```

**Warning** The `MYSQL_ROOT_USER` user is always created with remote access. It's suggested that the `MYSQL_ROOT_PASSWORD` env variable is always specified to set a password for the `MYSQL_ROOT_USER` user. In case you want to allow the `MYSQL_ROOT_USER` user to access the database without a password set the environment variable `ALLOW_EMPTY_PASSWORD=yes`. **This is recommended only for development**.

### Allowing empty passwords

By default, the MySQL image expects all the available passwords to be set. In order to allow empty passwords, it is necessary to set the `ALLOW_EMPTY_PASSWORD=yes` env variable. This env variable is only recommended for testing or development purposes. We strongly recommend specifying the `MYSQL_ROOT_PASSWORD` for any other scenario.

```console
$ docker run --name mysql -e ALLOW_EMPTY_PASSWORD=yes ghcr.io/bitcompat/mysql:latest
```

### Setting character set and collation

It is possible to configure the character set and collation used by default by the database with the following environment variables:

- `MYSQL_CHARACTER_SET`: The default character set to use. Default: `utf8`
- `MYSQL_COLLATE`: The default collation to use. Default: `utf8_general_ci`

### Creating a database on first run

By passing the `MYSQL_DATABASE` environment variable when running the image for the first time, a database will be created. This is useful if your application requires that a database already exists, saving you from having to manually create the database using the MySQL client.

```console
$ docker run --name mysql \
    -e ALLOW_EMPTY_PASSWORD=yes \
    -e MYSQL_DATABASE=my_database \
    ghcr.io/bitcompat/mysql:latest
```

### Creating a database user on first run

You can create a restricted database user that only has permissions for the database created with the [`MYSQL_DATABASE`](#creating-a-database-on-first-run) environment variable. To do this, provide the `MYSQL_USER` environment variable and to set a password for the database user provide the `MYSQL_PASSWORD` variable. MySQL supports different authentication mechanisms, such as `caching_sha2_password` or `mysql_native_password`. To set it, use the `MYSQL_AUTHENTICATION_PLUGIN` variable.

```console
$ docker run --name mysql \
  -e ALLOW_EMPTY_PASSWORD=yes \
  -e MYSQL_USER=my_user \
  -e MYSQL_PASSWORD=my_password \
  -e MYSQL_DATABASE=my_database \
  -e MYSQL_AUTHENTICATION_PLUGIN=mysql_native_password \
  ghcr.io/bitcompat/mysql:latest
```

**Note!** The `root` user will be created with remote access and without a password if `ALLOW_EMPTY_PASSWORD` is enabled. Please provide the `MYSQL_ROOT_PASSWORD` env variable instead if you want to set a password for the `root` user.

### Setting up a replication cluster

A **zero downtime** MySQL master-slave [replication](https://dev.mysql.com/doc/refman/8.0/en/server-options.html) cluster can easily be setup with the Bitnami MySQL Docker image using the following environment variables:

- `MYSQL_REPLICATION_MODE`: The replication mode. Possible values `master`/`slave`. No defaults.
- `MYSQL_REPLICATION_USER`: The replication user created on the master on first run. No defaults.
- `MYSQL_REPLICATION_PASSWORD`: The replication users password. No defaults.
- `MYSQL_MASTER_HOST`: Hostname/IP of replication master (slave parameter). No defaults.
- `MYSQL_MASTER_PORT_NUMBER`: Server port of the replication master (slave parameter). Defaults to `3306`.
- `MYSQL_MASTER_ROOT_USER`: User on replication master with access to `MYSQL_DATABASE` (slave parameter). Defaults to `root`
- `MYSQL_MASTER_ROOT_PASSWORD`: Password of user on replication master with access to `MYSQL_DATABASE` (slave parameter). No defaults.

In a replication cluster you can have one master and zero or more slaves. When replication is enabled the master node is in read-write mode, while the slaves are in read-only mode. For best performance its advisable to limit the reads to the slaves.

#### Step 1: Create the replication master

The first step is to start the MySQL master.

```console
$ docker run --name mysql-master \
  -e MYSQL_ROOT_PASSWORD=master_root_password \
  -e MYSQL_REPLICATION_MODE=master \
  -e MYSQL_REPLICATION_USER=my_repl_user \
  -e MYSQL_REPLICATION_PASSWORD=my_repl_password \
  -e MYSQL_USER=my_user \
  -e MYSQL_PASSWORD=my_password \
  -e MYSQL_DATABASE=my_database \
  ghcr.io/bitcompat/mysql:latest
```

In the above command the container is configured as the `master` using the `MYSQL_REPLICATION_MODE` parameter. A replication user is specified using the `MYSQL_REPLICATION_USER` and `MYSQL_REPLICATION_PASSWORD` parameters.

#### Step 2: Create the replication slave

Next we start a MySQL slave container.

```console
$ docker run --name mysql-slave --link mysql-master:master \
  -e MYSQL_REPLICATION_MODE=slave \
  -e MYSQL_REPLICATION_USER=my_repl_user \
  -e MYSQL_REPLICATION_PASSWORD=my_repl_password \
  -e MYSQL_MASTER_HOST=mysql-master \
  -e MYSQL_MASTER_ROOT_PASSWORD=master_root_password \
  ghcr.io/bitcompat/mysql:latest
```

In the above command the container is configured as a `slave` using the `MYSQL_REPLICATION_MODE` parameter. The `MYSQL_MASTER_HOST`, `MYSQL_MASTER_ROOT_USER` and `MYSQL_MASTER_ROOT_PASSWORD` parameters are used by the slave to connect to the master. It also takes a dump of the existing data in the master server. The replication user credentials are specified using the `MYSQL_REPLICATION_USER` and `MYSQL_REPLICATION_PASSWORD` parameters and should be the same as the one specified on the master.

You now have a two node MySQL master/slave replication cluster up and running. You can scale the cluster by adding/removing slaves without incurring any downtime.

### Configuration file

The image looks for user-defined configurations in `/opt/bitnami/mysql/conf/my_custom.cnf`. Create a file named `my_custom.cnf` and mount it at `/opt/bitnami/mysql/conf/my_custom.cnf`.

For example, in order to override the `max_allowed_packet` directive:

#### Step 1: Write your `my_custom.cnf` file with the following content.

```config
[mysqld]
max_allowed_packet=32M
```

#### Step 2: Run the MySQL image with the designed volume attached.

```console
$ docker run --name mysql \
    -p 3306:3306 \
    -e ALLOW_EMPTY_PASSWORD=yes \
    -v /path/to/my_custom.cnf:/opt/bitnami/mysql/conf/my_custom.cnf:ro \
    -v /path/to/mysql-persistence:/bitnami/mysql/data \
    ghcr.io/bitcompat/mysql:latest
```

After that, your changes will be taken into account in the server's behaviour.

Refer to the [MySQL server option and variable reference guide](https://dev.mysql.com/doc/refman/8.0/en/server-options.html) for the complete list of configuration options.

#### Overwrite the main Configuration file

It is also possible to use your custom `my.cnf` and overwrite the main configuration file.

```console
$ docker run --name mysql -v /path/to/my.cnf:/opt/bitnami/mysql/conf/my.cnf:ro ghcr.io/bitcompat/mysql:latest
```

## Customize this image

The Bitnami MySQL Docker image is designed to be extended, so it can be used as the base image for your custom configuration.

### Extend this image

Before extending this image, please note there are certain configuration settings you can modify using the original image:

- Settings that can be adapted using environment variables. For instance, you can change the ports used by MySQL, by setting the environment variables `MYSQL_PORT_NUMBER` or the character set using `MYSQL_CHARACTER_SET` respectively.

If your desired customizations cannot be covered using the methods mentioned above, extend the image. To do so, create your own image using a Dockerfile with the format below:

```Dockerfile
FROM ghcr.io/bitcompat/mysql
### Put your customizations below
...
```

Here is an example of extending the image with the following modifications:

- Install the `vim` editor
- Modify the MySQL configuration file
- Modify the ports used by MySQL
- Change the user that runs the container

```Dockerfile
FROM ghcr.io/bitcompat/mysql

### Change user to perform privileged actions
USER 0
### Install 'vim'
RUN install_packages vim
### Revert to the original non-root user
USER 1001

### modify configuration file.
RUN ini-file set --section "mysqld" --key "collation-server" --value "utf8_general_ci" "/opt/bitnami/mysql/conf/my.cnf"

### Modify the ports used by MySQL by default
## It is also possible to change these environment variables at runtime
ENV MYSQL_PORT_NUMBER=3307
EXPOSE 3307

### Modify the default container user
USER 1002
```

## Logging

The Bitnami MySQL Docker image sends the container logs to the `stdout`. To view the logs:

```console
$ docker logs mysql
```

To increase the verbosity on intialization or add extra debug information, you can assign the `BITNAMI_DEBUG` environment variable to `true`.

You can configure the containers [logging driver](https://docs.docker.com/engine/admin/logging/overview/) using the `--log-driver` option if you wish to consume the container logs differently. In the default configuration docker uses the `json-file` driver.

### Slow query logs

By default, MySQL doesn't enable [slow query log](https://dev.mysql.com/doc/refman/8.0/en/slow-query-log.html) to record the SQL queries that take a long time to perform. You can modify these settings using the following environment variables:

- `MYSQL_ENABLE_SLOW_QUERY`: Whether to enable slow query logs. Default: `0`
- `MYSQL_LONG_QUERY_TIME`: How much time, in seconds, defines a slow query. Default: `10.0`

### Slow filesystems

In some platforms, the filesystem used for persistence could be slow. That could cause the database to take extra time to be ready. If that's the case, you can configure the `MYSQL_INIT_SLEEP_TIME` environment variable to make the initialization script to wait extra time (in seconds) before proceeding with the configuration operations.

## Maintenance

### Upgrade this image

Bitnami provides up-to-date versions of MySQL, including security patches, soon after they are made upstream. We recommend that you follow these steps to upgrade your container.

#### Step 1: Get the updated image

```console
$ docker pull ghcr.io/bitcompat/mysql:latest
```

#### Step 2: Stop and backup the currently running container

Stop the currently running container using the command

```console
$ docker stop mysql
```

Next, take a snapshot of the persistent volume `/path/to/mysql-persistence` using:

```console
$ rsync -a /path/to/mysql-persistence /path/to/mysql-persistence.bkp.$(date +%Y%m%d-%H.%M.%S)
```

#### Step 3: Remove the currently running container

```console
$ docker rm -v mysql
```

#### Step 4: Run the new image

Re-create your container from the new image.

```console
$ docker run --name mysql ghcr.io/bitcompat/mysql:latest
```

## Contributing

We'd love for you to contribute to this container. You can request new features by creating an [issue](https://github.com/bitnami/containers/issues) or submitting a [pull request](https://github.com/bitnami/containers/pulls) with your contribution.

## Issues

If you encountered a problem running this container, you can file an [issue](https://github.com/bitnami/containers/issues/new/choose). For us to provide better support, be sure to fill the issue template.

## License

Copyright &copy; 2022 Bitnami

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
