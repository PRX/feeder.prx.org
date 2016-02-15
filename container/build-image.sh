#!/usr/bin/env bash
# Build the docker image and push it to the ECR repository

# load environment variables from file
while read line; do export "$line"; done < .deploy
export REPO_STRING="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$BASE_NAME.prx.org:$VERSION"

echo "Building the image"
docker-compose build

# The worker uses the same image as the web, so only label and push web
docker tag -f ${BASE_NAME}prxorg_$BASE_NAME $REPO_STRING

echo "Exporting to $REPO_STRING"
ECR_LOGIN=$(aws ecr get-login)
eval $ECR_LOGIN
aws ecr create-repository --repository-name=$BASE_NAME.prx.org || true

docker push $REPO_STRING
