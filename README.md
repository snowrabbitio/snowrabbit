![Logo](logo.png)

Snowrabbit is a looking glass network app that displays latency information between sites. It is useful for a datacenter or regional network to measure latency between all connections. It can also be used for multi-homed networks.

## Features
- Simple installation that requires docker and a database for the master, and docker for the probes.
- Probes auto register to the master once the proper data is placed in the startup default file
- Shows ping and traceroute data for all connections
- Color coding shows latent and down connections

## Installation

### Master

#### Systemd scripts
Deploy the systemd scripts that come with the master in the `systemd` directory. The main service file should be placed in `/etc/systemd/system/` and the default file in `/etc/default/`.  Values should be edited to reflect the current logging and database configuration.

#### /etc/default/snowrabbitio-master
in `/etc/default/snowrabbitio-master` update the following:
```console
LOGGER_LEVEL="info"
LISTEN_PORT=8090
```

#### Database
Decide which database you are going to use. Snowrabbit currently supports sqlite and mysql.

##### Sqlite
Define the following in the default file:
```console
DB_TYPE = "sqlite"
DB_DATABASE = "snowrabbit"
DB_DATABASE_PATH = "/var/lib/db"
```

##### Mysql
Define the following in the default file:
```console
DB_TYPE = "mysql"
DB_USER = "snowrabbit"
DB_PASS = "abc123"
DB_HOST = "db.snowrabbit.io"
DB_PORT = "3306"
DB_DATABASE = "snowrabbit"
```
Verify that the master can connect to the database instance. If the database is created, all tables will be automatically created.

### Probe

#### Systemd scripts
Deploy the systemd scripts that come with the master in the `systemd` directory. The main service file should be placed in `/etc/systemd/system/snowrabbitio-probe.service` and the default file in `/etc/default/snowrabbitio-probe`.  Values should be edited to reflect the current logging and database configuration.

#### /etc/default/snowrabbitio-master
```console
MASTER_HOST=demo.snowrabbit.io
MASTER_PORT=8090
PROBE_SECRET=abc123. # Secret is obtained after the probe checks in but before it is registered.
PROBE_SITE=nyc1
LOGGER_LEVEL="info"
```

### Register probes
After probes are started up and are pinging the master, they will be shown in the unregistered probes list:
http://demo.snowrabbit.io:8090/list_probes

You can use the pre-generated secret, or create your own secret, and click `Register` to register your probe. You should then update the secret variable in the default file and restart the probe.
