#!/bin/bash

DIRECTORY_NAME=$1
IMAGE_NAME=$DIRECTORY_NAME
CONTAINER_NAME="$IMAGE_NAME-container"

cat << EOT > package.json
{
  "name": "$IMAGE_NAME",
  "devDependencies": {},
  "scripts": {
    "docker:build": "docker stop $CONTAINER_NAME || true && docker rm $CONTAINER_NAME || true && docker build -t $IMAGE_NAME . --progress=plain",
    "docker:run": "docker stop $CONTAINER_NAME || true && docker rm $CONTAINER_NAME || true && docker run -d -p 8080:8080 --name $CONTAINER_NAME $IMAGE_NAME",
    "docker:stop": "docker stop $CONTAINER_NAME",
    "docker:exec": "docker exec -it $CONTAINER_NAME /bin/sh",
    "test:smoke": "curl -s http://localhost:8080/healthcheck | jq .",
    "test:integration": "cd api/collection/$DIRECTORY_NAME && bru run"
  }
}
EOT
