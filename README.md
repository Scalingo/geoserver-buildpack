# buildpack: GeoServer

This buildpack downloads and installs GeoServer into a Scalingo app image.

**Disclaimer**:

> This buildpack has been tested on Scalingo with GeoServer 2.21.1 only.
>
> It has a few [requirements](#requirements), [default settings](#default-settings)
and [known limitations](#known-limitations) that you should be aware of.
>
> It is highly recommended to setup your GeoServer following state-of-the-art
recommandations, such as the ones that can be found in the
[GeoCat documentation](https://www.geocat.net/docs/geoserver-enterprise/2022/welcome/index.html).
>
> It is also highly recommended to follow the best practicess and security
advises that can be found in the [GeoCat documentation](https://www.geocat.net/docs/geoserver-enterprise/2020.5/security/index.html).

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

1. Downloads GeoServer if necessary (when the requested version is not in
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

#### `GEOSERVER_ENABLE_WEBUI`

When set, enables GeoServer's web administration interface.\
A **restart** of the application is required for the change to be effective.\
Defaults to being unset (Web UI is disabled by default)

#### `GEOSERVER_ENABLE_LOGIN_AUTOCOMPLETE`

When set, enables login auto-complete on GeoServer's web administration
interface.\
A **restart** of the application is required for the change to be effective.\
Defaults to being unset (auto-complete is disabled by default)

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


## Requirements

This buildpack requires a PostgreSQL database addon with the PostGIS extension
enabled. See [Managing PostgreSQL Extensions](https://doc.scalingo.com/databases/postgresql/extensions)
for further details.


## Default settings

This buildpack makes sure a few sane defaults are set:

### Workspace

The [`GEOSERVER_WORKSPACE_NAME`](#GEOSERVER_WORKSPACE_NAME) workspace is
created and enabled.

Setting the `GEOSERVER_WORKSPACE_NAME` environment variable is mandatory.

### Datastore

The [`GEOSERVER_DATASTORE_NAME`](#GEOSERVER_DATASTORE_NAME) datastore is
created and linked to the PostGIS addon of your application.

Setting the `GEOSERVER_DATASTORE_NAME` environment variable is mandatory.

### GeoServer logging

Logging is configured to output to `stdout`. This makes sure Scalingo can
handle the logs and present them in the dashboard.

This is a platform requirement and can't be bypassed.

### GeoWebCache Limit

The GeoWebCache disk space is limited to 5 GiB.

This is a platform requirement and can't be bypassed.

### GeoWebCache Tile Removal Policy

The GeoWebCache tile removal policy is set to `Least Recently Used`, which
means that tiles are removed from the cache based on date of last access.

### GeoServer Web Administration Interface

The web administration interface is disabled by default.

It can be enabled by setting [`GEOSERVER_ENABLE_WEBUI`](#GEOSERVER_ENABLE_WEBUI),
although **we don't recommend it**.

### Login Auto-Complete

The login form auto-complete is disabled by default.

It can be enabled by setting [`GEOSERVER_ENABLE_LOGIN_AUTOCOMPLETE`](#GEOSERVER_ENABLE_LOGIN_AUTOCOMPLETE),
although **we don't recommend it**.


## Known limitations

### GeoServer configuration does not persist

> **Warning**\
> **GeoServer stores its configuration on a regular filesystem, which
is not supported by Scalingo. GeoServer's configuration will be lost each time
you deploy or restart the app.**

To avoid this, you **MUST** provide a `configure-geoserver.sh` script at the
root of your project and make API calls. This script is executed during the
*`BUILD`* phase of your application. After that phase, GeoServer's
configuration **should not** be modified. The configuration files resulting of
the API calls are available when the application enters the *`RUN`* phase.

Ideally, these API calls should create styles, layers, or even additional
workspace(s), datastore(s),... (see [Configuration examples](#configuration-examples)
below).

> **Warning**\
> **You have to make sure the configuration deployed during the *`BUILD`* phase
will persist when entering the *`RUN`* phase.** Our experience show that it's
not always the case. Calling the GeoWebCache API, for example, won't work.

> **Warning**\
> **You have to trigger a new deployment of your application each time the
configuration changes or if the database settings change** (the latter
remaining very unlikely to happen).


## Configuration examples

To create a new style, you can add the following command in your
`configure-geoserver.sh` script:

```bash
curl \
    --request POST http://localhost:4231/rest/styles \
    --user admin:geoserver \
    --header "Content-Type: application/vnd.ogc.sld+xml" \
    --data "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <StyledLayerDescriptor version=\"1.0.0\"
     xsi:schemaLocation=\"http://www.opengis.net/sld StyledLayerDescriptor.xsd\"
     xmlns=\"http://www.opengis.net/sld\"
     xmlns:ogc=\"http://www.opengis.net/ogc\"
     xmlns:xlink=\"http://www.w3.org/1999/xlink\"
     xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">
        <NamedLayer>
            <Name>dark-blue-line</Name>
            <UserStyle>
                <Name>dark-blue-line</Name>
                <Title>dark-blue-line</Title>
                <FeatureTypeStyle>
                    <Rule>
                        <Name>rule1</Name>
                        <Title>road</Title>
                        <Abstract>A solid blue line with a 5 pixel width</Abstract>
                        <LineSymbolizer>
                            <Stroke>
                                <CssParameter name=\"stroke\">#0000FF</CssParameter>
                                <CssParameter name=\"stroke-width\">5</CssParameter>
                            </Stroke>
                        </LineSymbolizer>
                    </Rule>
                </FeatureTypeStyle>
            </UserStyle>
        </NamedLayer>
    </StyledLayerDescriptor>"

```

Or, to do the same, you can create a file called `dark-blue-line.xml` in
a directory called `geoserver` at the root of your project and put the XML
content in it:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<StyledLayerDescriptor version="1.0.0"
 xsi:schemaLocation="http://www.opengis.net/sld StyledLayerDescriptor.xsd"
 xmlns="http://www.opengis.net/sld"
 xmlns:ogc="http://www.opengis.net/ogc"
 xmlns:xlink="http://www.w3.org/1999/xlink"
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <NamedLayer>
        <Name>dark-blue-line</Name>
        <UserStyle>
            <Name>dark-blue-line</Name>
            <Title>dark-blue-line</Title>
            <FeatureTypeStyle>
                <Rule>
                    <Name>rule1</Name>
                    <Title>road</Title>
                    <Abstract>A solid blue line with a 5 pixel width</Abstract>
                    <LineSymbolizer>
                        <Stroke>
                            <CssParameter name="stroke">#0000FF</CssParameter>
                            <CssParameter name="stroke-width">5</CssParameter>
                        </Stroke>
                    </LineSymbolizer>
                </Rule>
            </FeatureTypeStyle>
        </UserStyle>
    </NamedLayer>
</StyledLayerDescriptor>
```

And then put the following command in your `configure-geoserver.sh` script:

```bash
curl \
    --request POST http://localhost:4231/rest/styles \
    --user admin:geoserver \
    --header "Content-Type: application/vnd.ogc.sld+xml" \
    --data @geoserver/dark-blue-line.xml
```

You can even create a style directly from a zip file containing the .sld and
the icons files, using the following command:

```bash
curl \
    --user admin:geoserver \
    --request POST http://127.0.0.1:4231/rest/workspaces/{workspaceName}/styles \
    --header "Content-Type: application/zip" \
    --data-binary @geoserver/dark-blue-line.zip
```

Depending on the API endpoint you want to use, you can also store the JSON
objects to import in files.

For example, to create a new layer, create a file called `my_layer.json` in the
`geoserver` directory, with the following content:

```json
{
    "layer": {
        "name": "my_layer",
        "path": "/",
        "type": "VECTOR",
        "defaultStyle": {
            "name": "my_layer_style",
            "href": "http://localhost:4231/rest/styles/my_layer_style.json"
        },
        "styles": {
            "@class": "linked-hash-set",
            "style": [
                {
                    "name": "burg",
                    "href": "http://localhost:4231/rest/styles/burg.json"
                },
                {
                    "name": "point",
                    "href": "http://localhost:4231/rest/styles/point.json"
                }
            ]
        },
        "resource": {
            "@class": "featureType",
            "name": "my_layer",
            "href": "http://localhost:4231/rest/workspaces/{workspaceName}/datastores/{datastoreName}/featuretypes/my_layer.json"
        },
        "attribution": {
            "logoWidth": 0,
            "logoHeight": 0
        }
    }

}
```

And add the following lines in your `configure-geoserver.sh` script:

```bash
curl \
    --request POST http://127.0.0.1:4231/rest/workspaces/{workspaceName}/datastores/{datastoreName}/featuretypes \
    --user admin:geoserver \
    --header 'Content-Type: application/json' \
    --data @geoserver/my_layer.json
```

The complete API documentation, as long as examples, can be found in the
[GeoServer API documentation](https://docs.geoserver.org/latest/en/user/rest/index.html#api).

