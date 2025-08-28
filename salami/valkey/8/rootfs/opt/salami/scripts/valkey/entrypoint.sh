#!/bin/sh
# Copyright Broadcom, Inc. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC1091

set -eu
# set -x # Uncomment for debugging

# Load Valkey environment variables
. /opt/salami/scripts/valkey-env.sh

# Load libraries
. /opt/salami/scripts/libbitnami.sh
. /opt/salami/scripts/libvalkey.sh

print_welcome_page

# Copy default config without overwriting existing files
debug "Copying files from $VALKEY_DEFAULT_CONF_DIR to $VALKEY_CONF_DIR"
mkdir -p "$VALKEY_CONF_DIR"
# Try non-clobber copy; fallback to manual if option unsupported
if ! cp -Rn "$VALKEY_DEFAULT_CONF_DIR"/. "$VALKEY_CONF_DIR" 2>/dev/null; then
  for p in "$VALKEY_DEFAULT_CONF_DIR"/* "$VALKEY_DEFAULT_CONF_DIR"/.[!.]* "$VALKEY_DEFAULT_CONF_DIR"/..?*; do
    [ -e "$p" ] || continue
    name=$(basename "$p")
    [ -e "$VALKEY_CONF_DIR/$name" ] || cp -R "$p" "$VALKEY_CONF_DIR/"
  done
fi

# Detect run.sh in args (avoid bash [[ ... ]])
case " $* " in
  *" /opt/salami/scripts/valkey/run.sh "*|*" /run.sh "*)
    info "** Starting Valkey setup **"
    /opt/salami/scripts/valkey/setup.sh
    info "** Valkey setup finished! **"
    exec "$@"
    ;;
  *)
    # If no arguments, or first arg is not an absolute path, run run.sh by default
    if [ "$#" -eq 0 ]; then
      exec /opt/salami/scripts/valkey/run.sh
    else
      exec "$@"
    fi
    ;;
esac