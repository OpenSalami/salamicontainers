#!/bin/sh
# Copyright Broadcom, Inc. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0

set -eu
# set -x # Uncomment for debugging

# Load Redis environment variables
. /opt/salami/scripts/redis-env.sh

# Load libraries
. /opt/salami/scripts/libos.sh
. /opt/salami/scripts/libredis.sh

# Ensure config file exists
if [ ! -f "${REDIS_BASE_DIR}/etc/redis.conf" ]; then
    echo "ERROR: Redis config not found at ${REDIS_BASE_DIR}/etc/redis.conf"
    exit 1
fi

# Parse CLI flags to pass to the 'redis-server' call
set -- "${REDIS_BASE_DIR}/etc/redis.conf" --daemonize no $REDIS_EXTRA_FLAGS "$@"

info "** Starting Redis **"
if am_i_root; then
    exec_as_user "$REDIS_DAEMON_USER" /opt/salami/redis/redis-server "$@"
else
    exec /opt/salami/redis/redis-server "$@"
fi