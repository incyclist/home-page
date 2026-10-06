#!/bin/bash

: "${DOCKER_HUB_PUSH_PASSWORD:?set DOCKER_HUB_PUSH_PASSWORD to push to the registry}"

version=$(git describe --tags --abbrev=0)
docker build -t docker-push.incyclist.com/incyclist/home-page:$version .
docker tag docker-push.incyclist.com/incyclist/home-page:$version docker-push.incyclist.com/incyclist/home-page:latest

docker login docker-push.incyclist.com -u ci-push -p "$DOCKER_HUB_PUSH_PASSWORD"
docker push docker-push.incyclist.com/incyclist/home-page:$version
docker push docker-push.incyclist.com/incyclist/home-page:latest
