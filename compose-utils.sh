#!/bin/bash
#
# ThingsBoard, Inc. ("COMPANY") CONFIDENTIAL
#
# Copyright © 2016-2025 ThingsBoard, Inc. All Rights Reserved.
#
# NOTICE: All information contained herein is, and remains
# the property of ThingsBoard, Inc. and its suppliers,
# if any.  The intellectual and technical concepts contained
# herein are proprietary to ThingsBoard, Inc.
# and its suppliers and may be covered by U.S. and Foreign Patents,
# patents in process, and are protected by trade secret or copyright law.
#
# Dissemination of this information or reproduction of this material is strictly forbidden
# unless prior written permission is obtained from COMPANY.
#
# Access to the source code contained herein is hereby forbidden to anyone except current COMPANY employees,
# managers or contractors who have executed Confidentiality and Non-disclosure agreements
# explicitly covering such access.
#
# The copyright notice above does not evidence any actual or intended publication
# or disclosure  of  this source code, which includes
# information that is confidential and/or proprietary, and is a trade secret, of  COMPANY.
# ANY REPRODUCTION, MODIFICATION, DISTRIBUTION, PUBLIC  PERFORMANCE,
# OR PUBLIC DISPLAY OF OR THROUGH USE  OF THIS  SOURCE CODE  WITHOUT
# THE EXPRESS WRITTEN CONSENT OF COMPANY IS STRICTLY PROHIBITED,
# AND IN VIOLATION OF APPLICABLE LAWS AND INTERNATIONAL TREATIES.
# THE RECEIPT OR POSSESSION OF THIS SOURCE CODE AND/OR RELATED INFORMATION
# DOES NOT CONVEY OR IMPLY ANY RIGHTS TO REPRODUCE, DISCLOSE OR DISTRIBUTE ITS CONTENTS,
# OR TO MANUFACTURE, USE, OR SELL ANYTHING THAT IT  MAY DESCRIBE, IN WHOLE OR IN PART.
#

function additionalComposeArgs() {
    source .env
    ADDITIONAL_COMPOSE_ARGS=""
    case $DATABASE in
        postgres)
        ADDITIONAL_COMPOSE_ARGS="-f docker-compose.postgres.yml"
        ;;
        hybrid)
        ADDITIONAL_COMPOSE_ARGS="-f docker-compose.hybrid.yml"
        ;;
        *)
        echo "Unknown DATABASE value specified in the .env file: '${DATABASE}'. Should be either 'postgres' or 'hybrid'." >&2
        exit 1
    esac
    echo $ADDITIONAL_COMPOSE_ARGS
}

function additionalComposeMonitoringArgs() {
    source .env

    if [ "$MONITORING_ENABLED" = true ]
    then
      ADDITIONAL_COMPOSE_MONITORING_ARGS="-f docker-compose.prometheus-grafana.yml"
      echo $ADDITIONAL_COMPOSE_MONITORING_ARGS
    else
      echo ""
    fi
}

function additionalComposeCacheArgs() {
    source .env
    CACHE_COMPOSE_ARGS=""
    CACHE="${CACHE:-redis}"
    case $CACHE in
        redis)
        CACHE_COMPOSE_ARGS="-f docker-compose.redis.yml"
        ;;
        redis-cluster)
        CACHE_COMPOSE_ARGS="-f docker-compose.redis-cluster.yml"
        ;;
        redis-sentinel)
        CACHE_COMPOSE_ARGS="-f docker-compose.redis-sentinel.yml"
        ;;
        *)
        echo "Unknown CACHE value specified in the .env file: '${CACHE}'. Should be either 'redis' or 'redis-cluster' or 'redis-sentinel'." >&2
        exit 1
    esac
    echo $CACHE_COMPOSE_ARGS
}

function additionalStartupServices() {
    source .env
    ADDITIONAL_STARTUP_SERVICES=""
    case $DATABASE in
        postgres)
        ADDITIONAL_STARTUP_SERVICES="$ADDITIONAL_STARTUP_SERVICES postgres"
        ;;
        hybrid)
        ADDITIONAL_STARTUP_SERVICES="$ADDITIONAL_STARTUP_SERVICES postgres cassandra"
        ;;
        *)
        echo "Unknown DATABASE value specified in the .env file: '${DATABASE}'. Should be either 'postgres' or 'hybrid'." >&2
        exit 1
    esac

    CACHE="${CACHE:-redis}"
    case $CACHE in
        redis)
        ADDITIONAL_STARTUP_SERVICES="$ADDITIONAL_STARTUP_SERVICES redis"
        ;;
        redis-cluster)
        ADDITIONAL_STARTUP_SERVICES="$ADDITIONAL_STARTUP_SERVICES redis-node-0 redis-node-1 redis-node-2 redis-node-3 redis-node-4 redis-node-5"
        ;;
        redis-sentinel)
        ADDITIONAL_STARTUP_SERVICES="$ADDITIONAL_STARTUP_SERVICES redis-master redis-slave redis-sentinel"
        ;;
        *)
        echo "Unknown CACHE value specified in the .env file: '${CACHE}'. Should be either 'redis' or 'redis-cluster' or 'redis-sentinel'." >&2
        exit 1
    esac

    echo $ADDITIONAL_STARTUP_SERVICES
}

function permissionList() {
    PERMISSION_LIST="
      799  799  tb-edge/log
      999  999  tb-edge/postgres
      "

    source .env

    if [ "$DATABASE" = "hybrid" ]; then
      PERMISSION_LIST="$PERMISSION_LIST
      999  999  tb-edge/cassandra
      "
    fi

    CACHE="${CACHE:-redis}"
    case $CACHE in
        redis)
          PERMISSION_LIST="$PERMISSION_LIST
          1001 1001 tb-edge/redis-data
          "
        ;;
        redis-cluster)
          PERMISSION_LIST="$PERMISSION_LIST
          1001 1001 tb-edge/redis-cluster-data-0
          1001 1001 tb-edge/redis-cluster-data-1
          1001 1001 tb-edge/redis-cluster-data-2
          1001 1001 tb-edge/redis-cluster-data-3
          1001 1001 tb-edge/redis-cluster-data-4
          1001 1001 tb-edge/redis-cluster-data-5
          "
        ;;
        redis-sentinel)
          PERMISSION_LIST="$PERMISSION_LIST
          1001 1001 tb-edge/redis-sentinel-data-master
          1001 1001 tb-edge/redis-sentinel-data-slave
          1001 1001 tb-edge/redis-sentinel-data-sentinel
          "
        ;;
        *)
        echo "Unknown CACHE value specified in the .env file: '${CACHE}'. Should be either 'redis' or 'redis-cluster' or 'redis-sentinel'." >&2
        exit 1
    esac

    echo "$PERMISSION_LIST"
}

function checkFolders() {
  EXIT_CODE=0
  PERMISSION_LIST=$(permissionList) || exit $?
  set -e
  while read -r USR GRP DIR
  do
    if [ -z "$DIR" ]; then # skip empty lines
          continue
    fi
    MESSAGE="Checking user ${USR} group ${GRP} dir ${DIR}"
    if [[ -d "$DIR" ]] &&
       [[ $(ls -ldn "$DIR" | awk '{print $3}') -eq "$USR" ]] &&
       [[ $(ls -ldn "$DIR" | awk '{print $4}') -eq "$GRP" ]]
    then
      MESSAGE="$MESSAGE OK"
    else
      if [ "$1" = "--create" ]; then
        echo "Create and chown: user ${USR} group ${GRP} dir ${DIR}"
        mkdir -p "$DIR" && sudo chown -R "$USR":"$GRP" "$DIR"
      else
        echo "$MESSAGE FAILED"
        EXIT_CODE=1
      fi
    fi
  done < <(echo "$PERMISSION_LIST")
  return $EXIT_CODE
}

function composeVersion() {
    #Checking whether "set -e" shell option should be restored after Compose version check
    FLAG_SET=false
    if [[ $SHELLOPTS =~ errexit ]]; then
        set +e
        FLAG_SET=true
    fi

    #Checking Compose V1 availablity
    docker-compose version >/dev/null 2>&1
    if [ $? -eq 0 ]; then status_v1=true; else status_v1=false; fi

    #Checking Compose V2 availablity
    docker compose version >/dev/null 2>&1
    if [ $? -eq 0 ]; then status_v2=true; else status_v2=false; fi

    COMPOSE_VERSION=""

    if $status_v2 ; then
        COMPOSE_VERSION="V2"
    elif $status_v1 ; then
        COMPOSE_VERSION="V1"
    else
        echo "Docker Compose plugin is not detected. Please check your environment." >&2
        exit 1
    fi

    echo $COMPOSE_VERSION

    if $FLAG_SET ; then set -e; fi
}
