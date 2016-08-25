#!/bin/bash

function usage {
    echo "usage: $0 [options]"
    echo "       -r|--region        If not provided, the region will be looked up via AWS metadata (optional on EC2-only)."
    echo "       -g|--registries    The AWS account IDs to use for the login. Space separated. (Ex: \"123456789101, 98765432101\")"
    echo "       -f|--file-location Where the dockercfg should be saved."
    echo "       -i|--interval      How often to loop and refresh credentials (optional - default is 21600 - 6 hours)."
    exit 1
}

function log {
    echo $(date -u) $1
}

while [[ $# > 1 ]]
do
key="$1"

case $key in
    -r|--region)
    REGION="$2"
    shift;;
    -g|--registries)
    REGISTRIES="$2"
    shift;;
    -f|--file-location)
    FILE_LOCATION="$2"
    shift;;
    -i|--interval)
    INTERVAL="$2"
    shift;;
    *)
            # unknown option
    ;;
esac
shift # past argument or value
done

if [ -z "$REGISTRIES" ]; then
    echo "Registry IDs are required."
    usage
fi

if [ -z "$FILE_LOCATION" ]; then
    echo "File location is required."
    usage
fi

if [ -z "$REGION" ]; then
    AZ=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
    REGION=${AZ%?}

    if [[ -z "$REGION" ]]; then
        echo "Region could not be determined."
        usage
    fi
fi

if [[ -z "$INTERVAL" ]]; then
    log "Custom interval not provided, defaulting to 21600 seconds - 6 hours"
    INTERVAL=21600
fi

JSON_LOCATION="$FILE_LOCATION/.docker/config.json"

while true; do
    for ACCOUNT_NUM in $REGISTRIES
    do
        log "Login started for account: $ACCOUNT_NUM"
        ECR_AUTH=$(aws ecr get-authorization-token --region $REGION --registry-ids $ACCOUNT_NUM --output json)

        AUTH_TOKEN=$(echo $ECR_AUTH | jq -r '.authorizationData[0].authorizationToken')
        ENDPOINT=$(echo $ECR_AUTH | jq -r '.authorizationData[0].proxyEndpoint')

        log "Endpoint found: $ENDPOINT"

        if [[ -z "$AUTH_TOKEN" || -z "$ENDPOINT" ]]; then
            log "Unable to locate ECR login auth information for account: $ACCOUNT_NUM. Skipping..."
            continue;
        fi

        ECR_JSON="{\"auths\": {\"$ENDPOINT\": {\"auth\": \"$AUTH_TOKEN\",\"email\": \"none\"}}}"
        ECR_JSON_PLAIN="{\"auth\": \"$AUTH_TOKEN\",\"email\": \"none\"}"

        # If a dockercfg file doesn't already exist (odd), we can just write and exit
        if [[ ! -f $JSON_LOCATION || ! -s $JSON_LOCATION ]]; then
            log "Docker config does not exist at $JSON_LOCATION, creating file"

            mkdir -p "$(dirname "$JSON_LOCATION")"
            echo "$ECR_JSON" > $JSON_LOCATION
            continue;
        fi

        log "Existing Docker config found at $JSON_LOCATION, updating file"

        # Otherwise, need to append or modify the new config to existing
        EXISTING_CFG=$(cat $JSON_LOCATION)
        NEW_CONFIG=$(echo $EXISTING_CFG | jq ".auths[\"$ENDPOINT\"]=$ECR_JSON_PLAIN")

        echo $NEW_CONFIG > $JSON_LOCATION

        log "Done credential update for account: $ACCOUNT_NUM"
    done

    # Create the final .tar.gz
    log "Creating Docker tar at $FILE_LOCATION/docker.tar.gz"
    cd $FILE_LOCATION && tar czf docker.tar.gz .docker

    log "Sleeping for $INTERVAL"
    sleep $INTERVAL
done
