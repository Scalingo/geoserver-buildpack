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

> **Warning**\
> **GeoServer stores its configuration on a regular filesystem, which
is not supported by Scalingo. GeoServer's configuration will be lost each time
you deploy or restart the app.**

To avoid this, you **MUST** provide a `configure-geoserver.sh` script at the
root of your project and make API calls. This script is executed during the
*`BUILD`* phase of your application. After that phase, GeoServer's
configuration **should not** be modified. The configuration files resulting of
the API calls are available when the application enters the *`RUN`* phase.

Ideally, these API calls should create additional workspace(s), datastore(s),
etc (see [Configuration examples](#configuration-examples) below).

> **Warning**\
> **This also means you will have to trigger a new deployment of your application
each time the configuration changes.**

### GeoServer Web Cache limit

The GeoServer Web Cache is limited to 1 GiB.


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

Security best practices and advises can be found in the
[GeoCat documentation](https://www.geocat.net/docs/geoserver-enterprise/2020.5/security/index.html).

