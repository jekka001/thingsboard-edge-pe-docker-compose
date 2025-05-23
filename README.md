# Docker configuration for ThingsBoard Edge Microservices

This folder containing scripts and Docker Compose configurations to run ThingsBoard Edge in Microservices mode.

## Prerequisites

ThingsBoard Edge Microservices are running in dockerized environment.
Before starting please make sure [Docker CE](https://docs.docker.com/install/) and [Docker Compose](https://docs.docker.com/compose/install/) are installed in your system.

## Installation

Before performing initial installation you can configure the type of database to be used with ThingsBoard Edge.
In order to set database type change the value of `DATABASE` variable in `.env` file to one of the following:

- `postgres` - use PostgreSQL database;
- `hybrid` - use PostgreSQL for entities database and Cassandra for timeseries database;

**NOTE**: According to the database type corresponding docker service will be deployed (see `docker-compose.postgres.yml`, `docker-compose.hybrid.yml` for details).

In order to set cache type change the value of `CACHE` variable in `.env` file to one of the following:

- `redis` - use Redis standalone cache (1 node - 1 master);
- `redis-cluster` - use Redis cluster cache (6 nodes - 3 masters, 3 slaves);
- `redis-sentinel` - use Redis sentinel cache (3 nodes - 1 master, 1 slave, 1 sentinel)

**NOTE**: According to the cache type corresponding docker service will be deployed (see `docker-compose.redis.yml`, `docker-compose.redis-cluster.yml`, `docker-compose.redis-sentinel.yml` for details).

Execute the following command to create log folders for the services and chown of these folders to the docker container users. 
To be able to change user, **chown** command is used, which requires sudo permissions (script will request password for a sudo access): 

`
$ ./docker-create-log-folders.sh
`

Execute the following command to run installation:

`
$ ./docker-install-tb.sh
`

## Running

Execute the following command to start services:

`
$ ./docker-start-services.sh
`

After a while when all services will be successfully started you can open `http://{your-host-ip}` in you browser (for ex. `http://localhost`).
You should see ThingsBoard Edge login page.

Use the credentials from the ThingsBoard account.

In case of any issues you can examine edge service logs for errors.
For example to see ThingsBoard Edge node logs execute the following command:

`
$ docker-compose logs -f tb-edge1 tb-edge2 tb-edge3
`

Or use `docker-compose ps` to see the state of all the containers.
Use `docker-compose logs --f` to inspect the logs of all running services.
See [docker-compose logs](https://docs.docker.com/compose/reference/logs/) command reference for details.

Execute the following command to stop services:

`
$ ./docker-stop-services.sh
`

Execute the following command to stop and completely remove deployed docker containers:

`
$ ./docker-remove-services.sh
`

Execute the following command to update particular or all services (pull newer docker image and rebuild container):

`
$ ./docker-update-service.sh [SERVICE...]
`

Where:

- `[SERVICE...]` - list of services to update (defined in docker-compose configurations). If not specified all services will be updated.

## Upgrading

In case when database upgrade is needed, execute the following commands:

```
$ ./docker-stop-services.sh
$ ./docker-upgrade-tb.sh
$ ./docker-start-services.sh
```

## Monitoring

If you want to enable monitoring with Prometheus and Grafana you need to set <b>MONITORING_ENABLED</b> environment variable to <b>true</b>.
After this Prometheus and Grafana containers will be deployed. You can reach Prometheus at `http://localhost:9090` and Grafana at `http://localhost:3000` (default login is `admin` and password `foobar`).
To change Grafana password you need to update `GF_SECURITY_ADMIN_PASSWORD` environment variable at `./monitoring/grafana/config.monitoring` file.
Dashboards are loaded from `./monitoring/grafana/provisioning/dashboards` directory.

If you want to add new monitoring jobs for Prometheus update `./monitoring/prometheus/prometheus.yml` file.
