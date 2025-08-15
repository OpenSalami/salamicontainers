#!/bin/sh
# Copyright Broadcom, Inc. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC1091

set -eu
# set -x # Uncomment this line for debugging purposes

# Load Grafana environment
. /opt/salami/scripts/grafana-env.sh

# Load libraries
. /opt/salami/scripts/libbitnami.sh
. /opt/salami/scripts/liblog.sh

is_exec() {
    # Checks if the first provided argument is executable or if only args was used
    exec_in_path="$(command -v "$1" 2>/dev/null || true)"
    if { [ -f "$1" ] && [ -x "$(realpath "$1" 2>/dev/null)" ]; } || { [ -n "$exec_in_path" ] && [ -x "$(realpath "$exec_in_path" 2>/dev/null)" ]; }; then
        return 0
    else
        return 1
    fi
}

print_welcome_page

# We add the copy from default config in the entrypoint to not break users
# bypassing the setup.sh logic. If the file already exists do not overwrite (in
# case someone mounts a configuration file in /opt/bitnami/postgresql/conf)
debug "Copying files from $GRAFANA_DEFAULT_CONF_DIR to $GRAFANA_CONF_DIR"
cp -nr "$GRAFANA_DEFAULT_CONF_DIR"/. "$GRAFANA_CONF_DIR"

if [ "$1" = "/opt/bitnami/scripts/grafana/run.sh" ] || ! is_exec "$1"; then
    # This catches the error-code from libgrafana.sh for the immediate exit when the grafana-operator is used. And ensure that the exit code is kept silently.
    /opt/bitnami/scripts/grafana/setup.sh || GRAFANA_OPERATOR_IMMEDIATE_EXIT=$?
    if [ "${GRAFANA_OPERATOR_IMMEDIATE_EXIT:-0}" -eq 255 ]; then
        exit 0
    elif [ "${GRAFANA_OPERATOR_IMMEDIATE_EXIT:-0}" -ne 0 ]; then
        exit "$GRAFANA_OPERATOR_IMMEDIATE_EXIT"
    fi
    /post-init.sh
    info "** Grafana setup finished! **"
fi

echo ""

if is_exec "$1"; then
    exec "$@"
else
    exec "/opt/salami/scripts/grafana/run.sh" "$@"
fi