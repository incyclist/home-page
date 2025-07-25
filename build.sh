#!/bin/bash

version=$(git describe --tags --abbrev=0)
docker build -t docker.incyclist.com/incyclist/home-page:$version .
docker push docker.incyclist.com/incyclist/home-page:$version

docker tag docker.incyclist.com/incyclist/home-page:$version docker.incyclist.com/incyclist/home-page:latest
docker push docker.incyclist.com/incyclist/home-page:latest

