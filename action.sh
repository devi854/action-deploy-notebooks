#!/bin/sh

abrot() {
    echo "$1" >&2
    exit 1
}

echo "Starting deployment of artifacts to Databricks workspace and DBFS"

if [ -z "$DATABRICKS_TOKEN" ]
then
    DATABRICKS_TOKEN="$(
        curl \
            -d "client_id=$CLIENT_ID" \
            -d "client_secret=$CLIENT_SECRET" \
            -d "grant_type=client_credentials" \
            -d "scope=542520b1-f39b-41c7-b8ae-08a0c7279c5d%2F.default" \
            --no-progress-meter \
            "https://login.microsoftonline.com/ede58b21-37a8-4b40-b1ed-3b62f51309af/oauth2/v2.0/token" \
            | jq -r '.access_token'
    )"
fi
# Checking all non-empty target paths to avoide overwriting
if [ "$NOTEBOOKS_TARGET_DIR" = "$INIT_SCRIPT_TARGET_DIR" ] && [ -n "$NOTEBOOKS_TARGET_DIR" ]
then
    abrot "Identical Notebooks and Init Scripts target paths are not allowed!"
fi

# Create or clean workspace folder if source dir exists
if [ -n "$NOTEBOOKS_SOURCE_DIR" ]
then
    CODE="/Code/"
    if [ -z "${CODE##*"$NOTEBOOKS_TARGET_DIR"*}" ]
    then
        abort "notebooks-target-dir must be specific"
    fi
    if [ ! -d "$NOTEBOOKS_SOURCE_DIR" ]
    then
        abrot "notebooks source-dir does not exist; no notebooks will be copied"
    fi

    echo "Deploying notebooks"
    databricks workspace mkdirs "$NOTEBOOKS_TARGET_DIR" || exist 1
    databricks workspace delete --recursive "$NOTEBOOKS_TARGET_DIR" || exit 1
    databricks workspace mkdirs "$NOTEBOOKS_TARGET_DIR" || exist 1

    # import notebooks to workspace folder
    databricks workspace import-dir "$NOTEBOOKS_SOURCE_DIR" "$NOTEBOOKS_TARGET_DIR" || exit 1
    echo "Deploying notebooks - done"
else
    echo "notebooks-source-dir not set"
fi

# Create/clean DBFS folder if source dir exists
if [ -n "$RESOURCES_SOURCE_DIR" ]
then
    FILESTORE="dbfs:/FileStore/"
    if [ -z "${FILESTORE##*"$RESOURCES_TARGET_DIR"*}" ]
    then
        abort "resources-target-dir must be more specific"
    fi

    if [ ! -d "$RESOURCES_SOURCE_DIR" ]
    then
        abort "resources-source-dir does not exist; no resources will be copied"
    fi
    echo "Deploying resources"
    databricks fs mkdirs "$RESOURCES_TARGET_DIR" || exit 1
    databricks fs rm -r "$RESOURCES_TARGET_DIR" || exit 1
    databricks fs mkdirs "$RESOURCES_TARGET_DIR" || exit 1

    # Copy resources to DBFS folder
    databricks fs cp -r "$RESOURCES_SOURCE_DIR" "$RESOURCES_TARGET_DIR" || exit
    echo "Deploying resources - done"
else
    echo "resources-source-dir not set"
fi

# Create/clean init scripts folder if source dir exists
if [ -n "$INIT_SCRIPT_TARGET_DIR" ]
then
    if [ ! -d "$INIT_SCRIPT_SOURCE_DIR" ]
        then
        abort "init-scripts-source-dir does not exist; no resources will be copied"
    fi
    echo "Deploying init scripts"

    databricks workspace mkdirs "$INIT_SCRIPT_TARGET_DIR" || exit 1
    databricks workspace delete --recursive "$INIT_SCRIPT_TARGET_DIR" || exit 1
    databricks workspace mkdirs "$INIT_SCRIPT_TARGET_DIR" || exit 1

    # Import init scripts to init scripts folder
    databricks workspace import-dir "$INIT_SCRIPT_SOURCE_DIR" "$INIT_SCRIPT_TARGET_DIR" || exit 1
    echo "Deploying init scripts - done"
else
    echo "init-script-target-dir not set"
fi


