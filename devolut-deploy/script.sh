#!/bin/bash

# Command for calling the script: `d deploy pandora dk production`

# Prompt for Vault token
# "Enter Vault token (https://vault.lokalflirt.dk): "

# Load config file variables (e.g. `source configs/pandora/dk/env.yaml`)
# `source` probably doesn't work with yaml, find some way to use yaml but load the variables
# so bash can use them - if it's not straightforward skip this for now (write them in format <key>=<value>

# Read AWS credentials from Vault (vault endpoint specified in config file)
# vault kv get -field=AWS_ACCESS_KEY_ID -mount="tool-test" aws

# Check whether kubeconfig for the specified cluster exists (for start just grep `cluster_name` in ~/.kube/config)
    # if not, generate kubeconf using awscli

# Prompt for image tag
# "Enter image tag: "

# Mock helmfile deployment (just echo the command which will be used)



parse_yaml() {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}


deploy_to_k8s() {
    HELMFILE=$1
    ACTION=$2
    PROJECT_NAME=$3
    CLUSTER=$4
    ENVIRONMENT=$5

    # Sets parsed yaml key-value variables with a prefix CONF_ 
    eval $(parse_yaml configs/pandora/dk/env.yaml "CONF_")

    VAULT_ADDR=$CONF_vault_endpoint
    export VAULT_ADDR
    export VAULT_TOKEN  # FROM INLINE COMMAND

    # Gets AWS credentials from Vault
    CONF_AWS_ACCESS_KEY_ID=$(vault kv get -field=AWS_ACCESS_KEY_ID -mount="tool-test" aws)
    CONF_AWS_SECRET_ACCESS_KEY=$(vault kv get -field=AWS_SECRET_ACCESS_KEY -mount="tool-test" aws)

    if [ $? -eq 0 ]; then
        echo "Vault secrets retrieved successfully"
    else
        echo "Failed to retrieve secrets from vault"
        exit 1
    fi

    case "$PROJECT_NAME" in
        "pandora") # TBD
        REGION=$CONF_app_REGION
        COUNTRY=$CONF_app_COUNTRY
        IMAGE_TAG="sha-{BITBUCKET_COMMIT::7}" # TBD
            case "$ENVIRONMENT" in
            "staging")
                # Check config before switching
                aws configure set aws_access_key_id $CONF_AWS_ACCESS_KEY_ID
                aws configure set aws_secret_access_key $CONF_AWS_SECRET_ACCESS_KEY
                aws eks update-kubeconfig --name "${REGION}-eks" --region $CONF_aws_region
                kubectl get pod -A
                echo "helmfile -e $ENVIRONMENT -f k8s/helmfile.${HELMFILE} $ACTION"
            ;;
            "production")
                aws configure set aws_access_key_id $CONF_AWS_ACCESS_KEY_ID
                aws configure set aws_secret_access_key $CONF_AWS_SECRET_ACCESS_KEY
                aws eks update-kubeconfig --name "${REGION}-eks" --region $CONF_aws_region
                echo "helmfile -e $ENVIRONMENT -f k8s/helmfile.${HELMFILE} $ACTION"
            ;;
            "dev")
                aws configure set aws_access_key_id $CONF_AWS_ACCESS_KEY_ID
                aws configure set aws_secret_access_key $CONF_AWS_SECRET_ACCESS_KEY
                aws eks update-kubeconfig --name "${REGION}-eks" --region $CONF_aws_region
                echo "helmfile -e $ENVIRONMENT -f k8s/helmfile.${HELMFILE} $ACTION"
            ;;
            *)
            echo "Unknown environment: $ENVIRONMENT"
            exit 1
            ;;
            esac
    ;;
        *)
        echo "Unknown project: $PROJECT_NAME"
        exit 1
    ;;
    esac
}

if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <HELMFILE> <ACTION> <PROJECT_NAME> <CLUSTER> <ENVIRONMENT>"
    exit 1
fi

deploy_to_k8s "$1" "$2" "$3" "$4" "$5"