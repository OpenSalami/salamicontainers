#!/bin/sh
# Copyright Broadcom, Inc. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC1091

set -eu
# set -x # Uncomment this line for debugging purposes

# Only execute init scripts once
if [ ! -f "/bitnami/grafana/.user_scripts_initialized" ] && [ -d "/docker-entrypoint-init.d" ]; then
    # Find all files, sort, and process each with all handlers in /post-init.d
    find "/docker-entrypoint-init.d" -type f | sort | while IFS= read -r init_script; do
        for init_script_type_handler in /post-init.d/*.sh; do
            "$init_script_type_handler" "$init_script"
        done
    done
    touch "/bitnami/grafana/.user_scripts_initialized"
fi