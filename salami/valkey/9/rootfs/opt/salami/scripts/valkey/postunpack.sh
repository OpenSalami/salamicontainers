#!/bin/sh
# Copyright Broadcom, Inc. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC1091

set -eu
# set -x # Uncomment for debugging

# Load Valkey environment variables
. /opt/salami/scripts/valkey-env.sh

# Load libraries
. /opt/salami/scripts/libvalkey.sh
. /opt/salami/scripts/libfs.sh

# Ensure required dirs exist
for dir in "$VALKEY_VOLUME_DIR" "$VALKEY_DATA_DIR" "$VALKEY_BASE_DIR" "$VALKEY_CONF_DIR" "$VALKEY_DEFAULT_CONF_DIR"; do
    ensure_dir_exists "$dir"
done

chmod -R g+rwX /salami "$VALKEY_VOLUME_DIR" "$VALKEY_BASE_DIR"

# Seed main config
cp "$VALKEY_BASE_DIR/etc/valkey-default.conf" "$VALKEY_CONF_FILE"
chmod g+rw "$VALKEY_CONF_FILE"

# Default Valkey config
info "Setting Valkey config file..."
valkey_conf_set port "$VALKEY_DEFAULT_PORT_NUMBER"
valkey_conf_set dir "$VALKEY_DATA_DIR"
valkey_conf_set pidfile "$VALKEY_PID_FILE"
valkey_conf_set daemonize yes
valkey_conf_set logfile ""
# Disable RDB (AOF enabled by default)
valkey_conf_set save ""

# Copy generated configs to the default directory (robust to empty dir)
for p in "$VALKEY_CONF_DIR"/* "$VALKEY_CONF_DIR"/.[!.]* "$VALKEY_CONF_DIR"/..?*; do
    [ -e "$p" ] || continue
    cp -R "$p" "$VALKEY_DEFAULT_CONF_DIR"/
done