#!/bin/sh
# Copyright Broadcom, Inc. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0
#
# Bitnami Redis library

# shellcheck disable=SC1091

# Load Generic Libraries
. /opt/salami/scripts/libfile.sh
. /opt/salami/scripts/liblog.sh
. /opt/salami/scripts/libnet.sh
. /opt/salami/scripts/libos.sh
. /opt/salami/scripts/libservice.sh
. /opt/salami/scripts/libvalidations.sh

# Functions

########################
# Retrieve a configuration setting value
# Globals:
#   REDIS_BASE_DIR
# Arguments:
#   $1 - key
#   $2 - conf file
# Returns:
#   None
#########################
redis_conf_get() {
    key="$1"
    conf_file="${2:-"${REDIS_BASE_DIR}/etc/redis.conf"}"
    grep -E "^[[:space:]]*$key " "$conf_file" | awk '{print $2}'
}

########################
# Set a configuration setting value
# Globals:
#   REDIS_BASE_DIR
# Arguments:
#   $1 - key
#   $2 - value
# Returns:
#   None
#########################
redis_conf_set() {
    key="$1"
    value="$2"
    # Sanitize inputs (basic for sh)
    value=$(printf '%s' "$value" | sed 's/\\/\\\\/g; s/&/\\&/g; s/?/\\?/g; s/[$\t\n\r]//g')
    [ -z "$value" ] && value="\"$value\""

    # Determine whether to enable the configuration for RDB persistence, if yes, do not enable the replacement operation
    if [ "$key" = "save" ]; then
        echo "$key $value" >> "${REDIS_BASE_DIR}/etc/redis.conf"
    else
        replace_in_file "${REDIS_BASE_DIR}/etc/redis.conf" "^#*[[:space:]]*$key .*" "$key $value" false
    fi
}

########################
# Unset a configuration setting value
# Globals:
#   REDIS_BASE_DIR
# Arguments:
#   $1 - key
# Returns:
#   None
#########################
redis_conf_unset() {
    key="$1"
    remove_in_file "${REDIS_BASE_DIR}/etc/redis.conf" "^[[:space:]]*$key .*" false
}

########################
# Get Redis version
# Globals:
#   REDIS_BASE_DIR
# Arguments:
#   None
# Returns:
#   Redis version
#########################
redis_version() {
    "${REDIS_BASE_DIR}/bin/redis-cli" --version | grep -E -o "[0-9]+\.[0-9]+\.[0-9]+"
}

########################
# Get Redis major version
# Globals:
#   REDIS_BASE_DIR
# Arguments:
#   None
# Returns:
#   Redis major version
#########################
redis_major_version() {
    redis_version | grep -E -o "^[0-9]+"
}

########################
# Check if redis is running
# Globals:
#   REDIS_BASE_DIR
# Arguments:
#   $1 - pid file
# Returns:
#   Boolean
#########################
is_redis_running() {
    pid_file="${1:-"${REDIS_BASE_DIR}/tmp/redis.pid"}"
    pid="$(get_pid_from_file "$pid_file")"
    if [ -z "$pid" ]; then
        return 1
    else
        is_service_running "$pid"
    fi
}

########################
# Check if redis is not running
# Globals:
#   REDIS_BASE_DIR
# Arguments:
#   $1 - pid file
# Returns:
#   Boolean
#########################
is_redis_not_running() {
    ! is_redis_running "$@"
}

########################
# Stop Redis
# Globals:
#   REDIS_*
# Arguments:
#   None
# Returns:
#   None
#########################
redis_stop() {
    pass="$(redis_conf_get "requirepass")"
    if is_boolean_yes "$REDIS_TLS_ENABLED"; then
        port="$(redis_conf_get "tls-port")"
    else
        port="$(redis_conf_get "port")"
    fi

    args=""
    [ -n "$pass" ] && args="$args -a $pass"
    [ "$port" != "0" ] && args="$args -p $port"

    debug "Stopping Redis"
    if am_i_root; then
        run_as_user "$REDIS_DAEMON_USER" "${REDIS_BASE_DIR}/bin/redis-cli" $args shutdown
    else
        "${REDIS_BASE_DIR}/bin/redis-cli" $args shutdown
    fi
}

########################
# Validate settings in REDIS_* env vars.
# Globals:
#   REDIS_*
# Arguments:
#   None
# Returns:
#   None
#########################
redis_validate() {
    debug "Validating settings in REDIS_* env vars.."
    error_code=0

    print_validation_error() {
        error "$1"
        error_code=1
    }

    empty_password_enabled_warn() {
        warn "You set the environment variable ALLOW_EMPTY_PASSWORD=${ALLOW_EMPTY_PASSWORD}. For safety reasons, do not use this flag in a production environment."
    }
    empty_password_error() {
        print_validation_error "The $1 environment variable is empty or not set. Set the environment variable ALLOW_EMPTY_PASSWORD=yes to allow the container to be started with blank passwords. This is recommended only for development."
    }

    if is_boolean_yes "$ALLOW_EMPTY_PASSWORD"; then
        empty_password_enabled_warn
    else
        [ -z "$REDIS_PASSWORD" ] && empty_password_error REDIS_PASSWORD
    fi
    if [ -n "$REDIS_REPLICATION_MODE" ]; then
        case "$REDIS_REPLICATION_MODE" in
            slave|replica)
                if [ -n "$REDIS_MASTER_PORT_NUMBER" ]; then
                    if ! validate_port "$REDIS_MASTER_PORT_NUMBER"; then
                        print_validation_error "An invalid port was specified in the environment variable REDIS_MASTER_PORT_NUMBER"
                    fi
                fi
                if ! is_boolean_yes "$ALLOW_EMPTY_PASSWORD" && [ -z "$REDIS_MASTER_PASSWORD" ]; then
                    empty_password_error REDIS_MASTER_PASSWORD
                fi
                ;;
            master)
                ;;
            *)
                print_validation_error "Invalid replication mode. Available options are 'master/replica'"
                ;;
        esac
    fi
    if is_boolean_yes "$REDIS_TLS_ENABLED"; then
        if [ "$REDIS_PORT_NUMBER" = "$REDIS_TLS_PORT_NUMBER" ] && [ "$REDIS_PORT_NUMBER" != "6379" ]; then
            print_validation_error "Environment variables REDIS_PORT_NUMBER and REDIS_TLS_PORT_NUMBER point to the same port number (${REDIS_PORT_NUMBER}). Change one of them or disable non-TLS traffic by setting REDIS_PORT_NUMBER=0"
        fi
        if [ -z "$REDIS_TLS_CERT_FILE" ]; then
            print_validation_error "You must provide a X.509 certificate in order to use TLS"
        elif [ ! -f "$REDIS_TLS_CERT_FILE" ]; then
            print_validation_error "The X.509 certificate file in the specified path ${REDIS_TLS_CERT_FILE} does not exist"
        fi
        if [ -z "$REDIS_TLS_KEY_FILE" ]; then
            print_validation_error "You must provide a private key in order to use TLS"
        elif [ ! -f "$REDIS_TLS_KEY_FILE" ]; then
            print_validation_error "The private key file in the specified path ${REDIS_TLS_KEY_FILE} does not exist"
        fi
        if [ -z "$REDIS_TLS_CA_FILE" ]; then
            if [ -z "$REDIS_TLS_CA_DIR" ]; then
                print_validation_error "You must provide either a CA X.509 certificate or a CA certificates directory in order to use TLS"
            elif [ ! -d "$REDIS_TLS_CA_DIR" ]; then
                print_validation_error "The CA certificates directory specified by path ${REDIS_TLS_CA_DIR} does not exist"
            fi
        elif [ ! -f "$REDIS_TLS_CA_FILE" ]; then
            print_validation_error "The CA X.509 certificate file in the specified path ${REDIS_TLS_CA_FILE} does not exist"
        fi
        if [ -n "$REDIS_TLS_DH_PARAMS_FILE" ] && [ ! -f "$REDIS_TLS_DH_PARAMS_FILE" ]; then
            print_validation_error "The DH param file in the specified path ${REDIS_TLS_DH_PARAMS_FILE} does not exist"
        fi
    fi

    [ "$error_code" -eq 0 ] || exit "$error_code"
}

########################
# Configure Redis replication
# Globals:
#   REDIS_BASE_DIR
# Arguments:
#   $1 - Replication mode
# Returns:
#   None
#########################
redis_configure_replication() {
    info "Configuring replication mode"

    redis_conf_set replica-announce-ip "${REDIS_REPLICA_IP:-$(get_machine_ip)}"
    redis_conf_set replica-announce-port "${REDIS_REPLICA_PORT:-$REDIS_MASTER_PORT_NUMBER}"
    if is_boolean_yes "$REDIS_TLS_ENABLED"; then
        redis_conf_set tls-replication yes
    fi
    if [ "$REDIS_REPLICATION_MODE" = "master" ]; then
        [ -n "$REDIS_PASSWORD" ] && redis_conf_set masterauth "$REDIS_PASSWORD"
    elif [ "$REDIS_REPLICATION_MODE" = "slave" ] || [ "$REDIS_REPLICATION_MODE" = "replica" ]; then
        if [ -n "$REDIS_SENTINEL_HOST" ]; then
            # Sentinel support omitted for sh version
            :
        fi
        wait-for-port --host "$REDIS_MASTER_HOST" "$REDIS_MASTER_PORT_NUMBER"
        [ -n "$REDIS_MASTER_PASSWORD" ] && redis_conf_set masterauth "$REDIS_MASTER_PASSWORD"
        redis_conf_set "replicaof" "$REDIS_MASTER_HOST $REDIS_MASTER_PORT_NUMBER"
    fi
}

########################
# Disable Redis command(s)
# Globals:
#   REDIS_BASE_DIR
# Arguments:
#   $1 - Comma-separated list of commands to disable
# Returns:
#   None
#########################
redis_disable_unsafe_commands() {
    # Split comma-separated list
    old_IFS="$IFS"
    IFS=','; set -- $REDIS_DISABLE_COMMANDS; IFS="$old_IFS"
    for cmd; do
        if grep -E -q "^[[:space:]]*rename-command[[:space:]]+$cmd[[:space:]]+\"\"[[:space:]]*$" "$REDIS_CONF_FILE"; then
            debug "$cmd was already disabled"
            continue
        fi
        echo "rename-command $cmd \"\"" >> "$REDIS_CONF_FILE"
    done
}

########################
# Redis configure permissions
# Globals:
#   REDIS_*
# Arguments:
#   None
# Returns:
#   None
#########################
redis_configure_permissions() {
    debug "Ensuring expected directories/files exist"
    for dir in "$REDIS_BASE_DIR" "$REDIS_DATA_DIR" "$REDIS_BASE_DIR/tmp" "$REDIS_LOG_DIR"; do
        ensure_dir_exists "$dir"
        if am_i_root; then
            chown "$REDIS_DAEMON_USER:$REDIS_DAEMON_GROUP" "$dir"
        fi
    done
}

########################
# Redis specific configuration to override the default one
# Globals:
#   REDIS_*
# Arguments:
#   None
# Returns:
#   None
#########################
redis_override_conf() {
    if [ ! -e "${REDIS_MOUNTED_CONF_DIR}/redis.conf" ]; then
        [ -n "$REDIS_REPLICATION_MODE" ] && redis_configure_replication
    fi
}

########################
# Ensure Redis is initialized
# Globals:
#   REDIS_*
# Arguments:
#   None
# Returns:
#   None
#########################
redis_initialize() {
    redis_configure_default
    redis_override_conf
}

#########################
# Append include directives to redis.conf
# Globals:
#   REDIS_*
# Arguments:
#   None
# Returns:
#   None
#########################
redis_append_include_conf() {
    if [ -f "$REDIS_OVERRIDES_FILE" ]; then
        redis_conf_set include "$REDIS_OVERRIDES_FILE"
        redis_conf_unset "include"
        echo "include $REDIS_OVERRIDES_FILE" >> "${REDIS_BASE_DIR}/etc/redis.conf"
    fi
}

########################
# Configures Redis permissions and general parameters (also used in redis-cluster container)
# Globals:
#   REDIS_*
# Arguments:
#   None
# Returns:
#   None
#########################
redis_configure_default() {
    info "Initializing Redis"
    rm -f "$REDIS_BASE_DIR/tmp/redis.pid"
    redis_configure_permissions

    if [ -e "${REDIS_MOUNTED_CONF_DIR}/redis.conf" ]; then
        if [ -e "$REDIS_BASE_DIR/etc/redis-default.conf" ]; then
            rm "${REDIS_BASE_DIR}/etc/redis-default.conf"
        fi
        cp "${REDIS_MOUNTED_CONF_DIR}/redis.conf" "${REDIS_BASE_DIR}/etc/redis.conf"
    else
        info "Setting Redis config file"
        if is_boolean_yes "$ALLOW_EMPTY_PASSWORD"; then
            redis_conf_set protected-mode no
        fi
        is_boolean_yes "$REDIS_ALLOW_REMOTE_CONNECTIONS" && redis_conf_set bind "0.0.0.0 ::"
        redis_conf_set appendonly "${REDIS_AOF_ENABLED}"

        if [ -z "$REDIS_RDB_POLICY" ]; then
            if is_boolean_yes "$REDIS_RDB_POLICY_DISABLED"; then
                redis_conf_set save ""
            fi
        else
            for i in $REDIS_RDB_POLICY; do
                redis_conf_set save "$(echo "$i" | sed 's/#/ /g')"
            done
        fi

        redis_conf_set port "$REDIS_PORT_NUMBER"
        if is_boolean_yes "$REDIS_TLS_ENABLED"; then
            if [ "$REDIS_PORT_NUMBER" = "6379" ] && [ "$REDIS_TLS_PORT_NUMBER" = "6379" ]; then
                redis_conf_set port 0
                redis_conf_set tls-port "$REDIS_TLS_PORT_NUMBER"
            else
                redis_conf_set tls-port "$REDIS_TLS_PORT_NUMBER"
            fi
            redis_conf_set tls-cert-file "$REDIS_TLS_CERT_FILE"
            redis_conf_set tls-key-file "$REDIS_TLS_KEY_FILE"
            if [ -z "$REDIS_TLS_CA_FILE" ]; then
                redis_conf_set tls-ca-cert-dir "$REDIS_TLS_CA_DIR"
            else
                redis_conf_set tls-ca-cert-file "$REDIS_TLS_CA_FILE"
            fi
            [ -n "$REDIS_TLS_KEY_FILE_PASS" ] && redis_conf_set tls-key-file-pass "$REDIS_TLS_KEY_FILE_PASS"
            [ -n "$REDIS_TLS_DH_PARAMS_FILE" ] && redis_conf_set tls-dh-params-file "$REDIS_TLS_DH_PARAMS_FILE"
            redis_conf_set tls-auth-clients "$REDIS_TLS_AUTH_CLIENTS"
        fi
        [ -n "$REDIS_IO_THREADS_DO_READS" ] && redis_conf_set "io-threads-do-reads" "$REDIS_IO_THREADS_DO_READS"
        [ -n "$REDIS_IO_THREADS" ] && redis_conf_set "io-threads" "$REDIS_IO_THREADS"

        if [ -n "$REDIS_PASSWORD" ]; then
            redis_conf_set requirepass "$REDIS_PASSWORD"
        else
            redis_conf_unset requirepass
        fi
        [ -n "$REDIS_DISABLE_COMMANDS" ] && redis_disable_unsafe_commands
        [ -n "$REDIS_ACLFILE" ] && redis_conf_set aclfile "$REDIS_ACLFILE"
        redis_append_include_conf
    fi
}