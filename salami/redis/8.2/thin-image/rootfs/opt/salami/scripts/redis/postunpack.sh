#!/bin/sh
# Copyright Broadcom, Inc. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC1091

set -eu
# set -x # Uncomment this line for debugging purposes

# Load Redis environment variables
. /opt/salami/scripts/redis-env.sh

# Load libraries
. /opt/salami/scripts/libredis.sh
. /opt/salami/scripts/libfs.sh

for dir in "$REDIS_VOLUME_DIR" "$REDIS_DATA_DIR" "$REDIS_BASE_DIR" "$REDIS_CONF_DIR" "$REDIS_DEFAULT_CONF_DIR" "${REDIS_BASE_DIR}/tmp" "${REDIS_LOG_DIR}"; do
    ensure_dir_exists "$dir"
done
chmod -R g+rwX /salami "$REDIS_VOLUME_DIR" "$REDIS_BASE_DIR"

cp "${REDIS_BASE_DIR}/etc/redis-default.conf" "$REDIS_CONF_FILE"
chmod g+rw "$REDIS_CONF_FILE"
# Default Redis config
info "Setting Redis config file..."
redis_conf_set port "$REDIS_DEFAULT_PORT_NUMBER"
redis_conf_set dir "$REDIS_DATA_DIR"
redis_conf_set pidfile "$REDIS_PID_FILE"
redis_conf_set daemonize yes

redis_conf_set logfile "" # Log to stdout

# Disable RDB persistence, AOF persistence already enabled.
redis_conf_set save ""

# Copy all initially generated configuration files to the default directory
cp -r "${REDIS_CONF_DIR}/"* "$REDIS_DEFAULT_CONF_DIR"

# Allow others writing in the writable dirs so it works with gid 1001
chmod o+w -R "$REDIS_CONF_DIR" "${REDIS_BASE_DIR}/tmp" "${REDIS_LOG_DIR}"