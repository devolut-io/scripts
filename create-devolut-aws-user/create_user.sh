#!/bin/bash

if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker and run this script again (installation steps: https://docs.docker.com/engine/install/)"
    exit 1
fi

if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_DEFAULT_REGION" ]; then
    echo "AWS credentials not provided. Please set AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_DEFAULT_REGION environment variables."
    exit 1
fi

docker run -d -i --name infra_tooling \
    -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
    -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
    -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION \
    devolut/infra-tooling bin/bash

docker exec -it infra_tooling apk add --no-cache git
docker exec -it infra_tooling git clone https://github.com/devolut-io/scripts.git
docker exec -it infra_tooling chmod +x /scripts/create-devolut-aws-user/script.sh
docker exec -it -w /scripts/create-devolut-aws-user/ infra_tooling /scripts/create-devolut-aws-user/script.sh

docker stop infra_tooling
docker rm infra_tooling

echo "Script execution completed. Thank you for your time."