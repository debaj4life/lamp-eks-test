#!/bin/bash
set -euo pipefail

ACCOUNT_ID=653135932463
REGION=eu-west-2
REPO=wordpress
IMAGE_TAG=1.0
ECR_URI=$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO

aws ecr create-repository --repository-name $REPO --region $REGION 2>/dev/null || true

aws ecr get-login-password --region $REGION \
| docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

docker build -t $REPO:$IMAGE_TAG ./docker

docker tag $REPO:$IMAGE_TAG $ECR_URI:$IMAGE_TAG
docker tag $REPO:$IMAGE_TAG $ECR_URI:latest

docker push $ECR_URI:$IMAGE_TAG
docker push $ECR_URI:latest

echo "Pushed $ECR_URI:$IMAGE_TAG and $ECR_URI:latest"