#!/bin/bash

# Command for calling the script: `d deploy pandora dk production`

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
get_vault_secrets() {
    # Sets parsed yaml key-value variables with a prefix CONF_
    eval $(parse_yaml configs/pandora/dk/env.yaml "CONF_")

    export VAULT_ADDR=$CONF_vault_endpoint
    read -s -p "Enter Vault token: " VAULT_TOKEN
    export VAULT_TOKEN

    # Gets AWS credentials from Vault
    AWS_ACCESS_KEY_ID=$(vault kv get -field=AWS_ACCESS_KEY_ID -mount="tool-test" aws)
    exit_on_error $? "Failed to retrieve AWS_ACCESS_KEY_ID from vault"
    export AWS_ACCESS_KEY_ID

    AWS_SECRET_ACCESS_KEY=$(vault kv get -field=AWS_SECRET_ACCESS_KEY -mount="tool-test" aws)
    exit_on_error $? "Failed to retrieve AWS_SECRET_ACCESS_KEY from vault"
    export AWS_SECRET_ACCESS_KEY
}

deploy_to_k8s() {
    HELMFILE=$1
    ACTION=$2
    PROJECT_NAME=$3
    COUNTRY=$4
    ENVIRONMENT=$5

    get_vault_secrets

    case "$PROJECT_NAME" in
        "pandora")
        REGION=$CONF_app_region

        while true; do
            read -p "Enter Image Tag: " IMAGE_TAG
            if [ -z "$IMAGE_TAG" ]; then
                echo "Image Tag cannot be empty. Please enter a valid tag."
            else
                export IMAGE_TAG
                break
            fi
        done

        case "$COUNTRY" in 
            "dk")
            case "$ENVIRONMENT" in
                "staging"|"production"|"dev")

                    # Checks for context and update it if necessary
                    if ! grep -q "$CONF_cluster_name" ~/.kube/config; then
                        echo "Kubeconfig for $CONF_cluster_name does not exist. Generating kubeconfig..."
                        aws eks update-kubeconfig --name "$CONF_cluster_name" --region $CONF_aws_region
                        exit_on_error $? "Failed to generate kubeconfig for $CONF_cluster_name"
                    else
                        current_context=$(kubectl config current-context)
                         if [[ ! $current_context == *"$CONF_cluster_name"* ]]; then
                            echo "Switching to Kubernetes context $CONF_cluster_name"
                            aws eks update-kubeconfig --name "$CONF_cluster_name" --region $CONF_aws_region
                            exit_on_error $? "Failed to switch to Kubernetes context $CONF_cluster_name"
                        fi
                    fi

                    kubectl get pod -A
                    echo "helmfile -e $ENVIRONMENT -f k8s/helmfile.${HELMFILE} $ACTION"
                ;;
                *)
                    echo "Unknown environment: $ENVIRONMENT"
                    exit 1
                ;;
            esac
        ;;
            *)
            echo "Unknown country: $COUNTRY"
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
    echo "Usage: $0 <HELMFILE> <ACTION> <PROJECT_NAME> <COUNTRY> <ENVIRONMENT>"
    exit 1
fi

deploy_to_k8s "$1" "$2" "$3" "$4" "$5"
