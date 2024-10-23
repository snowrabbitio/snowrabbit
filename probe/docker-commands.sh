#!/bin/bash

DOCKER_ID=snowrabbitio
APP=probe

CONTROLLER_HOST=controller.snowrabbit.io
CONTROLLER_PORT=443
PROBE_USE_SSL=true

case $1 in
  build)
    echo "BUILD"
    rm -rf src/common
    cp -r ../common src
    docker build -t $DOCKER_ID/$APP .
    ;;

  build-nocache)
    echo "BUILD NOCACHE"
    rm -rf src/common
    cp -r ../common src
    docker build --no-cache -t $DOCKER_ID/$APP .
    ;;

  start|run)
    echo "RUN"
    #### REMOVED --rm
    docker run --name $APP -d -eCONTROLLER_HOST=$CONTROLLER_HOST -eCONTROLLER_PORT=$CONTROLLER_PORT -ePROBE_SITE=$PROBE_SITE -ePROBE_SECRET=$PROBE_SECRET -ePROBE_INTERVAL=$PROBE_INTERVAL -ePROBE_USE_SSL=$PROBE_USE_SSL $DOCKER_ID/$APP
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
    DT=`date +"%Y%m%d%H%M%S"`
    docker tag $DOCKER_ID/$APP:latest $DOCKER_ID/$APP:$DT
    docker push $DOCKER_ID/$APP:$DT
    ;;

  pull)
    echo "PULL"
    docker pull $DOCKER_ID/$APP
    ;;

  *)
    echo "Usage: $0 <build|start|stop|restart>"
    ;;
esac

