#!/bin/bash

DOCKER_ID=snowrabbitio
APP=webui

case $1 in
  build)
    echo "BUILD"
    docker build -t $DOCKER_ID/$APP .
    ;;

  start|run)
    echo "RUN"
    #### Removed --rm
    docker run --name $APP -d -p 8090:4567 -eLOGGER_LEVEL=$LOGGER_LEVEL -eDB_TYPE=$DB_TYPE -eDB_USER=$DB_USER -eDB_PASS=$DB_PASS -eDB_HOST=$DB_HOST -eDB_PORT=$DB_PORT -eDB_DATABASE=$DB_DATABASE -eADMIN_USER=$ADMIN_USER -eADMIN_PASS=$ADMIN_PASS $DOCKER_ID/$APP
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
