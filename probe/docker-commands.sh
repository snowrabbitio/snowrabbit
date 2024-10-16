#!/bin/bash

DOCKER_ID=snowrabbitio
APP=probe

case $1 in
  build)
    echo "BUILD"
    docker build -t $DOCKER_ID/$APP .
    ;;

  start|run)
    echo "RUN"
    #### REMOVED --rm
    docker run --name $APP -d -eMASTER_HOST=$MASTER_HOST -eMASTER_PORT=$MASTER_PORT -ePROBE_SITE=$PROBE_SITE -ePROBE_SECRET=$PROBE_SECRET $DOCKER_ID/$APP
    ;;

  stop)
    echo "STOP"
    docker stop $APP
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
    docker rm $APP
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

