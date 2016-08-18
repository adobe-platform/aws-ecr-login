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

while true; do
    for ACCOUNT_NUM in $REGISTRIES
    do
        log "Login started for account: $ACCOUNT_NUM"
        ECR_AUTH=$(aws ecr get-authorization-token --region $REGION --registry-ids $ACCOUNT_NUM --output json)

        AUTH_TOKEN=$(echo $ECR_AUTH | jq -r '.authorizationData[0].authorizationToken')
        ENDPOINT=$(echo $ECR_AUTH | jq -r '.authorizationData[0].proxyEndpoint')

        log "Endpoint found: $ENDPOINT"

        if [[ -z "$AUTH_TOKEN" || -z "$ENDPOINT" ]]; then
            log "Unable to locate ECR login auth information"
            exit 1
        fi

        ECR_JSON="{\"auths\": {\"$ENDPOINT\": {\"auth\": \"$AUTH_TOKEN\",\"email\": \"none\"}}}"
        ECR_JSON_PLAIN="{\"auth\": \"$AUTH_TOKEN\",\"email\": \"none\"}"

        # If a dockercfg file doesn't already exist (odd), we can just write and exit
        if [[ ! -f $FILE_LOCATION || ! -s $FILE_LOCATION ]]; then
            log "Docker config does not exist in file location, creating file"

            mkdir -p "$(dirname "$FILE_LOCATION")"
            echo "$ECR_JSON" > $FILE_LOCATION
            continue;
        fi

        log "Existing Docker config found, updating file"

        # Otherwise, need to append or modify the new config to existing
        EXISTING_CFG=$(cat $FILE_LOCATION)
        NEW_CONFIG=$(echo $EXISTING_CFG | jq ".auths[\"$ENDPOINT\"]=$ECR_JSON_PLAIN")

        echo $NEW_CONFIG > $FILE_LOCATION

        log "Done credential update for account: $ACCOUNT_NUM"
    done

    log "Sleeping for $INTERVAL"
    sleep $INTERVAL
done
