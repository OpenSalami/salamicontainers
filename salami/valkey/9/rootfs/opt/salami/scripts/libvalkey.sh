#!/bin/sh
# Copyright Broadcom, Inc. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0
#
# Valkey library (sh-compatible)

# shellcheck disable=SC1091

# Load Generic Libraries (Salami paths)
. /opt/salami/scripts/libfile.sh
. /opt/salami/scripts/liblog.sh
. /opt/salami/scripts/libnet.sh
. /opt/salami/scripts/libos.sh
. /opt/salami/scripts/libservice.sh
. /opt/salami/scripts/libvalidations.sh

# Helpers
_escape_sed() {
    # Escape \ / & for safe sed replacement
    printf '%s' "$1" | sed -e 's/[\\/&]/\\&/g'
}

trim_newlines_tabs() {
    # Remove literal newlines/tabs/carriage returns
    # BusyBox sed supports \r
    printf '%s' "$1" | tr -d '\n\r\t'
}

########################
# Retrieve a configuration setting value
# Globals:
#   VALKEY_BASE_DIR
# Arguments:
#   $1 - key
#   $2 - conf file (optional)
#########################
valkey_conf_get() {
    key="${1:?missing key}"
    conf_file="${2:-"${VALKEY_BASE_DIR}/etc/valkey.conf"}"
    if grep -q -E "^[[:space:]]*$key[[:space:]]+" "$conf_file"; then
        grep -E "^[[:space:]]*$key[[:space:]]+" "$conf_file" | awk '{print $2}'
    fi
}

########################
# Set a configuration setting value
# Globals:
#   VALKEY_BASE_DIR
# Arguments:
#   $1 - key
#   $2 - value
#########################
valkey_conf_set() {
    key="${1:?missing key}"
    value="${2-}"

    value="$(trim_newlines_tabs "$value")"
    esc="$(_escape_sed "$value")"

    # If value is empty and key is logfile, write logfile ""
    if [ "$key" = "logfile" ] && [ -z "$value" ]; then
        value='""'
        esc='""'
    fi

    if [ "$key" = "save" ]; then
        echo "$key $value" >> "${VALKEY_BASE_DIR}/etc/valkey.conf"
    else
        # If key exists, replace; else, append
        if grep -q -E "^[[:space:]]*$key[[:space:]]+" "${VALKEY_BASE_DIR}/etc/valkey.conf"; then
            replace_in_file "${VALKEY_BASE_DIR}/etc/valkey.conf" "^#*[[:space:]]*${key}[[:space:]].*" "${key} ${esc}" false
        else
            echo "${key} ${value}" >> "${VALKEY_BASE_DIR}/etc/valkey.conf"
        fi
    fi
}

########################
# Unset a configuration setting value
# Globals:
#   VALKEY_BASE_DIR
# Arguments:
#   $1 - key
#########################
valkey_conf_unset() {
    key="${1:?missing key}"
    remove_in_file "${VALKEY_BASE_DIR}/etc/valkey.conf" "^[[:space:]]*$key[[:space:]].*" false
}

########################
# Get Valkey version
# Globals:
#   VALKEY_BASE_DIR
#########################
valkey_version() {
    "${VALKEY_BASE_DIR}/bin/valkey-cli" --version | grep -E -o "[0-9]+\.[0-9]+\.[0-9]+"
}

########################
# Get Valkey major version
#########################
valkey_major_version() {
    valkey_version | grep -E -o "^[0-9]+"
}

########################
# Check if valkey is running
# Globals:
#   VALKEY_BASE_DIR
# Arguments:
#   $1 - pid file (optional)
# Returns:
#   success if running
#########################
is_valkey_running() {
    pid_file="${1:-"${VALKEY_BASE_DIR}/tmp/valkey.pid"}"
    pid="$(get_pid_from_file "$pid_file")"
    if [ -z "$pid" ]; then
        return 1
    else
        is_service_running "$pid"
    fi
}

########################
# Check if valkey is not running
#########################
is_valkey_not_running() {
    if is_valkey_running "$@"; then
        return 1
    fi
    return 0
}

########################
# Stop Valkey
# Globals:
#   VALKEY_*
#########################
valkey_stop() {
    is_valkey_running || return 0

    pass="$(valkey_conf_get "requirepass")"
    if is_boolean_yes "$VALKEY_TLS_ENABLED"; then
        port="$(valkey_conf_get "tls-port")"
    else
        port="$(valkey_conf_get "port")"
    fi

    debug "Stopping Valkey"
    set --
    [ -n "$pass" ] && set -- "$@" -a "$pass"
    [ "$port" != "0" ] && [ -n "$port" ] && set -- "$@" -p "$port"

    if am_i_root; then
        run_as_user "$VALKEY_DAEMON_USER" "${VALKEY_BASE_DIR}/bin/valkey-cli" "$@" shutdown
    else
        "${VALKEY_BASE_DIR}/bin/valkey-cli" "$@" shutdown
    fi
}

########################
# Validate settings in VALKEY_* env vars.
# Globals:
#   VALKEY_*
#########################
valkey_validate() {
    debug "Validating settings in VALKEY_* env vars.."
    error_code=0

    print_validation_error() {
        error "$1"
        error_code=1
    }

    if is_boolean_yes "$ALLOW_EMPTY_PASSWORD"; then
        warn "ALLOW_EMPTY_PASSWORD=${ALLOW_EMPTY_PASSWORD}. Do not use in production."
    else
        if [ -z "${VALKEY_PASSWORD:-}" ]; then
            print_validation_error "VALKEY_PASSWORD is empty. Set ALLOW_EMPTY_PASSWORD=yes to allow blank passwords (dev only)."
        fi
    fi

    if [ -n "${VALKEY_REPLICATION_MODE:-}" ]; then
        if [ "$VALKEY_REPLICATION_MODE" = "replica" ]; then
            if [ -n "${VALKEY_PRIMARY_PORT_NUMBER:-}" ]; then
                if ! err="$(validate_port "$VALKEY_PRIMARY_PORT_NUMBER" 2>&1)"; then
                    print_validation_error "Invalid VALKEY_PRIMARY_PORT_NUMBER: $err"
                fi
            fi
            if ! is_boolean_yes "$ALLOW_EMPTY_PASSWORD" && [ -z "${VALKEY_PRIMARY_PASSWORD:-}" ]; then
                print_validation_error "VALKEY_PRIMARY_PASSWORD is required for replica mode"
            fi
        elif [ "$VALKEY_REPLICATION_MODE" != "primary" ]; then
            print_validation_error "Invalid replication mode. Use 'primary' or 'replica'."
        fi
    fi

    if is_boolean_yes "$VALKEY_TLS_ENABLED"; then
        if [ "$VALKEY_PORT_NUMBER" = "$VALKEY_TLS_PORT_NUMBER" ] && [ "$VALKEY_PORT_NUMBER" != "6379" ]; then
            print_validation_error "VALKEY_PORT_NUMBER and VALKEY_TLS_PORT_NUMBER are equal (${VALKEY_PORT_NUMBER}). Change one or set VALKEY_PORT_NUMBER=0"
        fi
        if [ -z "${VALKEY_TLS_CERT_FILE:-}" ]; then
            print_validation_error "VALKEY_TLS_CERT_FILE is required when TLS is enabled"
        elif [ ! -f "$VALKEY_TLS_CERT_FILE" ]; then
            print_validation_error "TLS cert file not found: ${VALKEY_TLS_CERT_FILE}"
        fi
        if [ -z "${VALKEY_TLS_KEY_FILE:-}" ]; then
            print_validation_error "VALKEY_TLS_KEY_FILE is required when TLS is enabled"
        elif [ ! -f "$VALKEY_TLS_KEY_FILE" ]; then
            print_validation_error "TLS key file not found: ${VALKEY_TLS_KEY_FILE}"
        fi
        if [ -z "${VALKEY_TLS_CA_FILE:-}" ]; then
            if [ -z "${VALKEY_TLS_CA_DIR:-}" ]; then
                print_validation_error "Provide VALKEY_TLS_CA_FILE or VALKEY_TLS_CA_DIR when TLS is enabled"
            elif [ ! -d "$VALKEY_TLS_CA_DIR" ]; then
                print_validation_error "TLS CA dir not found: ${VALKEY_TLS_CA_DIR}"
            fi
        elif [ ! -f "$VALKEY_TLS_CA_FILE" ]; then
            print_validation_error "TLS CA file not found: ${VALKEY_TLS_CA_FILE}"
        fi
        if [ -n "${VALKEY_TLS_DH_PARAMS_FILE:-}" ] && [ ! -f "$VALKEY_TLS_DH_PARAMS_FILE" ]; then
            print_validation_error "TLS DH params file not found: ${VALKEY_TLS_DH_PARAMS_FILE}"
        fi
    fi

    if [ "$error_code" -ne 0 ]; then
        exit "$error_code"
    fi
}

########################
# Configure Valkey replication
# Globals:
#   VALKEY_BASE_DIR
# Arguments:
#   None (uses env)
#########################
valkey_configure_replication() {
    info "Configuring replication mode"

    valkey_conf_set replica-announce-ip "${VALKEY_REPLICA_IP:-$(get_machine_ip)}"
    valkey_conf_set replica-announce-port "${VALKEY_REPLICA_PORT:-$VALKEY_PRIMARY_PORT_NUMBER}"

    if is_boolean_yes "$VALKEY_TLS_ENABLED"; then
        valkey_conf_set tls-replication yes
    fi

    if [ "$VALKEY_REPLICATION_MODE" = "primary" ]; then
        if [ -n "${VALKEY_PASSWORD:-}" ]; then
            valkey_conf_set primaryauth "$VALKEY_PASSWORD"
        fi
    elif [ "$VALKEY_REPLICATION_MODE" = "replica" ]; then
        if [ -n "${VALKEY_SENTINEL_HOST:-}" ]; then
            cmd="valkey-cli -h ${VALKEY_SENTINEL_HOST} -p ${VALKEY_SENTINEL_PORT_NUMBER}"
            if is_boolean_yes "$VALKEY_TLS_ENABLED"; then
                cmd="$cmd --tls --cert ${VALKEY_TLS_CERT_FILE} --key ${VALKEY_TLS_KEY_FILE}"
                if [ -z "${VALKEY_TLS_CA_FILE:-}" ]; then
                    cmd="$cmd --cacertdir ${VALKEY_TLS_CA_DIR}"
                else
                    cmd="$cmd --cacert ${VALKEY_TLS_CA_FILE}"
                fi
            fi
            out="$(sh -c "$cmd sentinel get-master-addr-by-name ${VALKEY_SENTINEL_PRIMARY_NAME}" | tr '\n' ' ')"
            VALKEY_PRIMARY_HOST=$(printf '%s' "$out" | awk '{print $1}')
            VALKEY_PRIMARY_PORT_NUMBER=$(printf '%s' "$out" | awk '{print $2}')
        fi
        wait-for-port --host "$VALKEY_PRIMARY_HOST" "$VALKEY_PRIMARY_PORT_NUMBER"
        if [ -n "${VALKEY_PRIMARY_PASSWORD:-}" ]; then
            valkey_conf_set primaryauth "$VALKEY_PRIMARY_PASSWORD"
        fi
        valkey_conf_set "replicaof" "$VALKEY_PRIMARY_HOST $VALKEY_PRIMARY_PORT_NUMBER"
    fi
}

########################
# Disable Valkey command(s)
# Globals:
#   VALKEY_CONF_FILE
#########################
valkey_disable_unsafe_commands() {
    [ -z "${VALKEY_DISABLE_COMMANDS:-}" ] && return 0
    # Split comma-separated list
    IFS_OLD=$IFS
    IFS=','; set -- $VALKEY_DISABLE_COMMANDS; IFS=$IFS_OLD
    debug "Disabling commands: $*"
    for cmd in "$@"; do
        if grep -E -q "^[[:space:]]*rename-command[[:space:]]+$cmd[[:space:]]+\"\"[[:space:]]*$" "$VALKEY_CONF_FILE"; then
            debug "$cmd was already disabled"
            continue
        fi
        echo "rename-command $cmd \"\"" >> "$VALKEY_CONF_FILE"
    done
}

########################
# Valkey configure permissions
# Globals:
#   VALKEY_*
#########################
valkey_configure_permissions() {
    debug "Ensuring expected directories/files exist"
    for dir in "${VALKEY_BASE_DIR}" "${VALKEY_DATA_DIR}" "${VALKEY_BASE_DIR}/tmp" "${VALKEY_LOG_DIR}"; do
        ensure_dir_exists "$dir"
        if am_i_root; then
            chown "$VALKEY_DAEMON_USER:$VALKEY_DAEMON_GROUP" "$dir"
        fi
    done
}

########################
# Valkey specific configuration override
# Globals:
#   VALKEY_*
#########################
valkey_override_conf() {
    if [ ! -e "${VALKEY_MOUNTED_CONF_DIR}/valkey.conf" ]; then
        if [ -n "${VALKEY_REPLICATION_MODE:-}" ]; then
            valkey_configure_replication
        fi
    fi
}

########################
# Ensure Valkey is initialized
#########################
valkey_initialize() {
    valkey_configure_default
    valkey_override_conf
}

#########################
# Append include directives to valkey.conf
#########################
valkey_append_include_conf() {
    if [ -f "$VALKEY_OVERRIDES_FILE" ]; then
        valkey_conf_set include "$VALKEY_OVERRIDES_FILE"
        valkey_conf_unset "include"
        echo "include $VALKEY_OVERRIDES_FILE" >> "${VALKEY_BASE_DIR}/etc/valkey.conf"
    fi
}

########################
# Configure Valkey defaults
# Globals:
#   VALKEY_*
#########################
valkey_configure_default() {
    info "Initializing Valkey"
    echo "DEBUG: Writing config to $VALKEY_BASE_DIR/etc/valkey.conf"
    ls -l "$VALKEY_BASE_DIR/etc"
    

    rm -f "$VALKEY_BASE_DIR/tmp/valkey.pid"

    valkey_configure_permissions

    if [ -e "${VALKEY_MOUNTED_CONF_DIR}/valkey.conf" ]; then
        if [ -e "$VALKEY_BASE_DIR/etc/valkey-default.conf" ]; then
            rm -f "${VALKEY_BASE_DIR}/etc/valkey-default.conf"
        fi
        cp "${VALKEY_MOUNTED_CONF_DIR}/valkey.conf" "${VALKEY_BASE_DIR}/etc/valkey.conf"
    else
        info "Setting Valkey config file"
        if is_boolean_yes "$ALLOW_EMPTY_PASSWORD"; then
            valkey_conf_set protected-mode no
        fi
        if is_boolean_yes "$VALKEY_ALLOW_REMOTE_CONNECTIONS"; then
            valkey_conf_set bind "0.0.0.0 ::"
        fi
        valkey_conf_set appendonly "${VALKEY_AOF_ENABLED}"

        if is_empty_value "${VALKEY_RDB_POLICY:-}"; then
            if is_boolean_yes "${VALKEY_RDB_POLICY_DISABLED:-}"; then
                valkey_conf_set save ""
            fi
        else
            for i in $VALKEY_RDB_POLICY; do
                saved="$(printf '%s' "$i" | sed 's/#/ /g')"
                valkey_conf_set save "$saved"
            done
        fi

        valkey_conf_set port "$VALKEY_PORT_NUMBER"

        if is_boolean_yes "$VALKEY_TLS_ENABLED"; then
            if [ "$VALKEY_PORT_NUMBER" = "6379" ] && [ "$VALKEY_TLS_PORT_NUMBER" = "6379" ]; then
                valkey_conf_set port 0
                valkey_conf_set tls-port "$VALKEY_TLS_PORT_NUMBER"
            else
                valkey_conf_set tls-port "$VALKEY_TLS_PORT_NUMBER"
            fi
            valkey_conf_set tls-cert-file "$VALKEY_TLS_CERT_FILE"
            valkey_conf_set tls-key-file "$VALKEY_TLS_KEY_FILE"
            if is_empty_value "${VALKEY_TLS_CA_FILE:-}"; then
                valkey_conf_set tls-ca-cert-dir "$VALKEY_TLS_CA_DIR"
            else
                valkey_conf_set tls-ca-cert-file "$VALKEY_TLS_CA_FILE"
            fi
            if [ -n "${VALKEY_TLS_KEY_FILE_PASS:-}" ]; then
                valkey_conf_set tls-key-file-pass "$VALKEY_TLS_KEY_FILE_PASS"
            fi
            [ -n "${VALKEY_TLS_DH_PARAMS_FILE:-}" ] && valkey_conf_set tls-dh-params-file "$VALKEY_TLS_DH_PARAMS_FILE"
            valkey_conf_set tls-auth-clients "$VALKEY_TLS_AUTH_CLIENTS"
        fi

        if ! is_empty_value "${VALKEY_IO_THREADS_DO_READS:-}"; then
            valkey_conf_set "io-threads-do-reads" "$VALKEY_IO_THREADS_DO_READS"
        fi
        if ! is_empty_value "${VALKEY_IO_THREADS:-}"; then
            valkey_conf_set "io-threads" "$VALKEY_IO_THREADS"
        fi

        if [ -n "${VALKEY_PASSWORD:-}" ]; then
            valkey_conf_set requirepass "$VALKEY_PASSWORD"
        else
            valkey_conf_unset requirepass
        fi

        if [ -n "${VALKEY_DISABLE_COMMANDS:-}" ]; then
            valkey_disable_unsafe_commands
        fi

        if [ -n "${VALKEY_ACLFILE:-}" ]; then
            valkey_conf_set aclfile "$VALKEY_ACLFILE"
        fi

        valkey_append_include_conf
        echo "correct configuration:"
        cat "$VALKEY_BASE_DIR/etc/valkey.conf"
        cat "$VALKEY_BASE_DIR/etc/valkey-default.conf"
    fi
}