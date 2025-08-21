#!/bin/sh
# Copyright Broadcom, Inc. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC1091

set -eu
# set -x # Uncomment this line for debugging purposes

# Load Redis environment variables
. /opt/salami/scripts/redis-env.sh

# Load libraries
. /opt/salami/scripts/libos.sh
. /opt/salami/scripts/libredis.sh

# Parse CLI flags to pass to the 'redis-server' call
set -- "${REDIS_BASE_DIR}/etc/redis.conf" --daemonize no $REDIS_EXTRA_FLAGS "$@"

info "** Starting Redis **"
if am_i_root; then
    exec_as_user "$REDIS_DAEMON_USER" redis-server "$@"
else
    exec redis-server "$@"
fi