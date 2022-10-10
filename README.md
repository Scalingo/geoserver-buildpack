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
workspace(s), the datastore(s), etc.

