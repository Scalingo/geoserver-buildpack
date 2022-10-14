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

3. Setup the app environment:

```bash
% scalingo --app my-geoserver env-set BUILDPACK_URL="https://github.com/Scalingo/geoserver-buildpack.git"
% scalingo --app my-geoserver env-set GEOSERVER_DATA_DIR="/app/geoserver-data"
% scalingo --app my-geoserver env-set JAVA_VERSION=17
```

4. Put your configuration files in your project directory.

5. Deploy:

```bash
% git push scalingo master
```

## Configuration

GeoServer stores its configuration on a regular filesystem, which is not
supported by Scalingo. You will lose your configuration each time you deploy or
restart the app.

To avoid this, you will have to provide a `configure-geoserver.sh` script at
the root of your project and make API calls. These API calls should create the
workspace(s), the datastore(s), etc (see [examples](#examples) below).

### Examples

To create a workspace called `my-workspace`, create `geoserver/workspace.json`
as follow:

```json
{
    "workspace": {
        "name": "my-workspace"
    }
}
```

Then, add the following lines in your `configure-geoserver.sh` script:

```bash
curl \
    --user admin:geoserver \
    --request "POST" \
    --header 'Content-Type: application/json' \
    --data @geoserver/workspace.json \
    "127.0.0.1:4231/rest/workspaces"
```

To create a *PostGIS* datastore called `my-datastore` in our previously created
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
    --request "POST" \
    --header 'Content-Type: application/json' \
    --data @geoserver/datastore.json \
    "127.0.0.1:4231/rest/workspaces/my-workspace/datastores"
```

The complete API documentation, as long as examples, can be found in the
[GeoServer API documentation](https://docs.geoserver.org/latest/en/user/rest/index.html#api).
