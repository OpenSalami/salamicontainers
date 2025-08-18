#!/bin/sh
# Copyright Broadcom, Inc. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC1091

set -eu
# set -x # Uncomment this line for debugging purposes

# Load Redis environment variables
. /opt/salami/scripts/redis-env.sh

# Load libraries
. /opt/salami/scripts/libbitnami.sh
. /opt/salami/scripts/libredis.sh

print_welcome_page

# Copy default config if not present
debug "Copying files from $REDIS_DEFAULT_CONF_DIR to $REDIS_CONF_DIR"
cp -nr "$REDIS_DEFAULT_CONF_DIR"/. "$REDIS_CONF_DIR"

case "$*" in
    *"/opt/salami/scripts/redis/run.sh"*|*"/run.sh"*)
        info "** Starting Redis setup **"
        /opt/salami/scripts/redis/setup.sh
        info "** Redis setup finished! **"
        ;;
esac

echo ""
exec "$@"