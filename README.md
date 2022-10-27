# buildpack: GeoServer

This buildpack downloads and installs GeoServer into a Scalingo app image.

## Usage

The following instructions should get you started:

1. Initialize a new git repository wherever you want:

```bash
% mkdir my-geoserver
% cd my-geoserver
% git init
```

2. Create the Scalingo app:

```bash
% scalingo create my-geoserver
% scalingo --app my-geoserver scale web:1:M
```

3. Add a PostgreSQL addon:

```bash
% scalingo --app my-geoserver addons-add postgresql postgresql-starter-512
```

4. Setup the app environment:

```bash
% scalingo --app my-geoserver env-set BUILDPACK_URL="https://github.com/Scalingo/geoserver-buildpack.git"
% scalingo --app my-geoserver env-set GEOSERVER_ADMIN_PASSWORD="s0_s3cret"
% scalingo --app my-geoserver env-set GEOSERVER_WORKSPACE_NAME="my-workspace"
% scalingo --app my-geoserver env-set GEOSERVER_DATASTORE_NAME="my-datastore"
```

5. [Configure](#geoserver-configuration-does-not-persist) GeoServer

6. Deploy:

```bash
% git push scalingo master
```

### Deployment workflow

During the *`BUILD`* phase, this buildpack:

1. Downloads GeoServer if necessary (when the requested version is not in\
   cache).
2. Installs the Java Runtime Environment.
3. Installs GeoServer.
4. Runs a temporary GeoServer on `localhost:4231`.
5. Setup a few things, such as the `GEOSERVER_WORKSPACE_NAME` workspace, and
   the `GEOSERVER_DATASTORE_NAME` datastore.
6. Executes the given configuration file, if any.
7. Enforces some configuration, such as disk quota, logging and *admin* account
   password.
6. Stops the temporary GeoServer.
7. Validates the build.

:tada: This process results into a scalable image that includes the
configuration, ready to be packaged into a container.

### Environment

The following environment variables are available for you to tweak your
deployment:

#### `GEOSERVER_ADMIN_PASSWORD`

Password of the *admin* user account.\
**Mandatory**

#### `GEOSERVER_WORKSPACE_NAME`

Name of the first workspace to create.\
**Mandatory**

#### `GEOSERVER_DATASTORE_NAME`

Name of the first datastore to create.\
This datastore will be linked to the PostgreSQL addon.\
**Mandatory**

#### `GEOSERVER_DATASTORE_DESCRIPTION`

Description of the first datastore to create.\
Defaults to `""` (empty).

#### `GEOSERVER_VERSION`

Version of GeoServer to install.\
Defaults to `2.21.1`

#### `GEOSERVER_CONFIG_SCRIPT`

Path to the file containing the configuration script.\
Defaults to `/app/configure-geoserver.sh`

#### `GEOSERVER_DATA_DIR`

Path to the directory where GeoServer stores its configuration file.\
Defaults to `/app/geoserver-data`

#### `JAVA_VERSION`

Java Runtime Environment to use to run GeoServer.\
Defaults to `11`

#### `JAVA_WEBAPP_RUNNER_VERSION`

Version of webapp runner to install and use.\
Defaults to `9.0.52.1`


## Known limitations

### GeoServer configuration does not persist

> **Danger**
> **GeoServer stores its configuration on a regular filesystem, which
is not supported by Scalingo. GeoServer's configuration will be lost each time
you deploy or restart the app.**

To avoid this, you can provide a `configure-geoserver.sh` script at the root
of your project and make API calls. This script is executed during the
*`BUILD`* phase of your application. After that phase, GeoServer's
configuration **should not** be modified. The configuration files resulting of
the API calls are available when the application enters the *`RUN`* phase.

Ideally, these API calls should create additional workspace(s), datastore(s),
etc (see [Configuration examples](#configuration-examples) below).

> **Warning**
> This also means you will have to trigger a new deployment of your application
each time the configuration changes.**

### GeoServer Web Cache limit

The GeoServer Web Cache is limited to 1 GiB.


## Configuration examples

To create a workspace called `my-workspace`, add the following lines in your
`configure-geoserver.sh` script:

```bash
curl \
    --user admin:geoserver \
    --request POST 127.0.0.1:4231/rest/workspaces \
    --header 'Content-Type: application/json' \
    --data '{"workspace": {"name": "my-workspace"} }'
```

You can also store the JSON objects to import in files. For example, to create
a *PostGIS* datastore called `my-datastore` in our previously created
`my-workspace` workspace, create `geoserver/datastore.json` as follow:

```json
{
    "dataStore": {
        "name": "my-datastore",
        "connectionParameters": {
            "entry": [
                {
                    "@key": "host",
                    "$": "my-db-host"
                },
                {
                    "@key": "port",
                    "$": "my-db-port"
                },
                {
                    "@key": "database",
                    "$": "my-db-name"
                },
                {
                    "@key": "user",
                    "$": "my-db-user"
                },
                {
                    "@key": "passwd",
                    "$": "my-db-password"
                },
                {
                    "@key": "dbtype",
                    "$": "postgis"
                }
            ]
        }
    }
}
```

Then, add the following lines in your `configure-geoserver.sh` script:

```bash
curl \
    --user admin:geoserver \
    --request POST 127.0.0.1:4231/rest/workspaces/my-workspace/datastores \
    --header 'Content-Type: application/json' \
    --data @geoserver/datastore.json
```

The complete API documentation, as long as examples, can be found in the
[GeoServer API documentation](https://docs.geoserver.org/latest/en/user/rest/index.html#api).

Security best practices and advises can be found in the
[GeoCat documentation](https://www.geocat.net/docs/geoserver-enterprise/2020.5/security/index.html).

