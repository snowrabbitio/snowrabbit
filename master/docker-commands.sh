#!/bin/bash

DOCKER_ID=snowrabbitio
APP=master
PROBE_SECRET=abc123

case $1 in
  build)
    echo "BUILD"
    docker build -t $DOCKER_ID/$APP .
    ;;

  start|run)
    echo "RUN"
    #### Removed --rm
    docker run --name $DOCKER_ID-$APP -d -ePROBE_SECRET=$PROBE_SECRET -p 8090:4567 -v ~/git/snowrabbit/master/db:/var/lib/db $DOCKER_ID/$APP
    ;;

  stop)
    echo "STOP"
    docker stop $DOCKER_ID-$APP
    ;;

  restart)
    echo "RESTART"
    $0 stop
    sleep 1
    $0 rm
    sleep 1
    $0 start
    ;;

  rm)
    echo "RM"
    docker rm $DOCKER_ID-$APP
    ;;

  push)
    echo "PUSH"
    docker push $DOCKER_ID/$APP
    ;;

  pull)
    echo "PULL"
    docker pull $DOCKER_ID/$APP
    ;;

  *)
    echo "Usage: $0 <build|start|stop|restart>"
    ;;
esac

