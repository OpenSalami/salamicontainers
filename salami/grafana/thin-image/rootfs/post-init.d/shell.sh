#!/bin/sh
# Copyright Broadcom, Inc. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0
#
# Executes custom shell init scripts

# shellcheck disable=SC1090,SC1091

set -eu
# set -x # Uncomment this line for debugging purposes

# Load libraries with logging functions
if [ -f /opt/salami/base/functions ]; then
    . /opt/salami/base/functions
else
    . /opt/salami/scripts/liblog.sh
fi

failure=0

for custom_init_script in "$@"; do
    case "$custom_init_script" in
        *.sh)
            if [ -x "$custom_init_script" ]; then
                info "Executing ${custom_init_script}"
                "$custom_init_script" || failure=1
            else
                info "Sourcing ${custom_init_script} as it is not executable by the current user, any error may cause initialization to fail"
                . "$custom_init_script" || failure=1
            fi
            if [ "$failure" -ne 0 ]; then
                error "Failed to execute ${custom_init_script}"
            fi
            ;;
        *)
            # Skip non-.sh files
            ;;
    esac
done

exit "$failure"