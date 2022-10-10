#!/bin/bash

DOCKER_ID=snowrabbitio
APP=probe
MASTER_HOST="http://192.168.1.200"
MASTER_PORT=8090
PROBE_SECRET=abc123
PROBE_SITE=ewr

case $1 in
  build)
    echo "BUILD"
    docker build -t $DOCKER_ID/$APP .
    ;;

  start|run)
    echo "RUN"
    #### REMOVED --rm
    docker run --name $APP -d -eMASTER_HOST=$MASTER_HOST -eMASTER_PORT=$MASTER_PORT -ePROBE_SITE=$PROBE_SITE -ePROBE_SECRET=$PROBE_SECRET -p 8091:4567 $DOCKER_ID/$APP
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

