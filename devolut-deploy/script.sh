#!/bin/bash

# Command for calling the script: `script.sh pandora dk production`

supported_projects=("pandora")
supported_countries=("dk")

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
exit_on_error() {
    exit_code=$1
    message=$2

    if [ $exit_code -ne 0 ]; then
        echo "$message"
        exit 1
    fi
}

get_aws_creds_from_vault() {
    export VAULT_ADDR=$CONF_vault_endpoint

    if [ -z "$VAULT_TOKEN" ]; then
        read -s -p "Enter Vault token ($CONF_vault_endpoint): " VAULT_TOKEN
        echo
        export VAULT_TOKEN
    else
        echo "Using Vault token from env."
    fi

    # Gets AWS credentials from Vault
    AWS_ACCESS_KEY_ID=$(vault kv get -field=AWS_ACCESS_KEY_ID -mount="tool-test" aws)
    exit_on_error $? "Failed to retrieve AWS_ACCESS_KEY_ID from vault"
    export AWS_ACCESS_KEY_ID

    AWS_SECRET_ACCESS_KEY=$(vault kv get -field=AWS_SECRET_ACCESS_KEY -mount="tool-test" aws)
    exit_on_error $? "Failed to retrieve AWS_SECRET_ACCESS_KEY from vault"
    export AWS_SECRET_ACCESS_KEY
}

check_params() {
    local project=$1
    local country=$2

    if [[ ! " ${supported_projects[*]} " =~ " $project " ]]; then
        echo "Unknown project: $project"
        exit 1
    fi

    if [[ ! " ${supported_countries[*]} " =~ " $country " ]]; then
        echo "Unknown country: $country"
        exit 1
    fi
}

read_image_tag() {
    if [ -z "$IMAGE_TAG" ]; then
        while true; do
            read -p "Enter Image Tag: " IMAGE_TAG
            echo
            if [ -z "$IMAGE_TAG" ]; then
                echo "Image Tag cannot be empty. Please enter a valid tag."
            else
                export IMAGE_TAG
                break
            fi
       done
    else
        echo "Using IMAGE_TAG from env ($IMAGE_TAG)"
    fi
}

deploy_to_k8s() {
    PROJECT_NAME=$1
    COUNTRY=$2
    ENVIRONMENT=$3

    check_params "$PROJECT_NAME" "$COUNTRY"

    # Parse yaml config for specific app/country and load it into vars prefixed with CONF_
    eval $(parse_yaml configs/$PROJECT_NAME/$COUNTRY/env.yaml "CONF_")

    get_aws_creds_from_vault

    read_image_tag

    mkdir -p ~/devolut/.kube
    KUBECONFIG_PATH=~/devolut/.kube/${CONF_cluster_name}.yaml

    if [ ! -f "$KUBECONFIG_PATH" ]; then
        echo "Kubeconfig for $CONF_cluster_name does not exist. Generating kubeconfig at $KUBECONFIG_PATH..."
        aws eks update-kubeconfig --name "$CONF_cluster_name" --region $CONF_aws_region --kubeconfig "$KUBECONFIG_PATH"
        exit_on_error $? "Failed to generate kubeconfig for $CONF_cluster_name at $KUBECONFIG_PATH"
    else
        echo "Using existing kubeconfig for $CONF_cluster_name at $KUBECONFIG_PATH"
    fi

    export KUBECONFIG=$KUBECONFIG_PATH

    kubectl get pod -A
    echo "helmfile -e $ENVIRONMENT -f k8s/helmfile.d deploy"
}
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <PROJECT_NAME> <COUNTRY> <ENVIRONMENT>"
    exit 1
fi

deploy_to_k8s $1 $2 $3
