#!/bin/sh
# Copyright Broadcom, Inc. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC1091

set -eu
# set -x # Uncomment for debugging

# Load Valkey environment variables
. /opt/salami/scripts/valkey-env.sh

# Load libraries
. /opt/salami/scripts/libos.sh
. /opt/salami/scripts/libfs.sh
. /opt/salami/scripts/libvalkey.sh

# Ensure Valkey environment variables settings are valid
valkey_validate

# Ensure Valkey daemon user exists when running as root
if am_i_root; then
    if ! id "$VALKEY_DAEMON_USER" >/dev/null 2>&1; then
        ensure_user_exists "$VALKEY_DAEMON_USER" --group "$VALKEY_DAEMON_GROUP"
    fi
fi

# Ensure Valkey is initialized
valkey_initialize