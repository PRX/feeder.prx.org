#!/usr/bin/env bash

# load environment variables from files
while read line; do export "$line"; done < .deploy

curl -sL https://raw.githubusercontent.com/PRX/meta.prx.org/master/bin/ecs-deploy > ecs-deploy
chmod +x ecs-deploy

image="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$BASE_NAME.prx.org:$VERSION"

services=( web worker )
for s in "${services[@]}"
do
  service="$BASE_NAME-$s-${ENV:-staging}"
  echo "Deploying $service for $image"
  AWS_PROFILE=ecs ./ecs-deploy --cluster prx-${ENV:-staging} --service-name $service --image $image --timeout 120
  rm -f def.old
done

rm -f ecs-deploy
