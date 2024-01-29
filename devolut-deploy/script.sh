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
