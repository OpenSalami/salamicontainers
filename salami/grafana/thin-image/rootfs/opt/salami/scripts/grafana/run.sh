#!/bin/sh
# Copyright Broadcom, Inc. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC1091

set -eu
# set -x # Uncomment this line for debugging purposes

# Load Grafana environment
. /opt/salami/scripts/grafana-env.sh

# Load libraries
. /opt/salami/scripts/libos.sh
. /opt/salami/scripts/liblog.sh

cmd="grafana"
# Build args as a plain string for POSIX sh
args="server \
  --homepath=${GF_PATHS_HOME} \
  --config=${GF_PATHS_CONFIG} \
  --pidfile=${GRAFANA_PID_FILE} \
  --packaging=docker \
  $@ \
  cfg:default.log.mode=console \
  cfg:default.paths.data=${GF_PATHS_DATA} \
  cfg:default.paths.logs=${GF_PATHS_LOGS} \
  cfg:default.paths.plugins=${GF_PATHS_PLUGINS} \
  cfg:default.paths.provisioning=${GF_PATHS_PROVISIONING}"

cd "$GRAFANA_BASE_DIR"

info "** Starting Grafana **"
if am_i_root; then
    # Use 'set --' to split args for exec_as_user
    # shellcheck disable=SC2086
    set -- $args
    exec_as_user "$GRAFANA_DAEMON_USER" "$cmd" "$@"
else
    # shellcheck disable=SC2086
    set -- $args
    exec "$cmd" "$@"
fi