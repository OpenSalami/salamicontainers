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
. /opt/salami/scripts/libvalkey.sh

# Build CLI args (config + daemonize=no + extra flags + user args)
orig_args="$*"
set -- "$VALKEY_BASE_DIR/etc/valkey.conf" "--daemonize" "no"

extra="${VALKEY_EXTRA_FLAGS:-}"
if [ -n "$extra" ]; then
    # shellcheck disable=SC2086
    set -- "$@" $extra
fi

if [ -n "$orig_args" ]; then
    # shellcheck disable=SC2086
    set -- "$@" $orig_args
fi

info "** Starting Valkey **"
if am_i_root; then
    exec_as_user "$VALKEY_DAEMON_USER"  /opt/salami/valkey/valkey-server "$@"
else
    exec /opt/salami/valkey/bin/valkey-server "$@"
fi