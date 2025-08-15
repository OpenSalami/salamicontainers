#!/bin/sh
# Copyright Broadcom, Inc. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0
#
# Bitnami Grafana library

# shellcheck disable=SC1091

# Load generic libraries
. /opt/salami/scripts/liblog.sh
. /opt/salami/scripts/libos.sh
. /opt/salami/scripts/libvalidations.sh
. /opt/salami/scripts/libversion.sh

# Load database library
if [ -f /opt/salami/scripts/libmysqlclient.sh ]; then
    . /opt/salami/scripts/libmysqlclient.sh
elif [ -f /opt/salami/scripts/libmysql.sh ]; then
    . /opt/salami/scripts/libmysql.sh
elif [ -f /opt/salami/scripts/libmariadb.sh ]; then
    . /opt/salami/scripts/libmariadb.sh
fi

########################
# Print the value of a Grafana environment variable
# Globals:
#   GF_*
#   GRAFANA_CFG_*
# Arguments:
#   $1 - variable name (e.g. PATHS_CONFIG)
# Returns:
#   The value in the environment variable
#########################
grafana_env_var_value() {
    name="${1:?missing name}"
    gf_env_var="GF_${name}"
    grafana_cfg_env_var="GRAFANA_CFG_${name}"
    eval gf_val=\${$gf_env_var:-}
    eval cfg_val=\${$grafana_cfg_env_var:-}
    if [ -n "$gf_val" ]; then
        echo "$gf_val"
    elif [ -n "$cfg_val" ]; then
        echo "$cfg_val"
    else
        error "${gf_env_var} or ${grafana_cfg_env_var} must be set"
    fi
}

########################
# Validate settings in GRAFANA_* env vars
# Globals:
#   GRAFANA_*
# Arguments:
#   None
# Returns:
#   0 if the validation succeeded, 1 otherwise
#########################
grafana_validate() {
    debug "Validating settings in GRAFANA_* environment variables..."
    error_code=0

    print_validation_error() {
        error "$1"
        error_code=1
    }
    check_path_exists() {
        if [ ! -e "$1" ]; then
            print_validation_error "The directory ${1} does not exist"
        fi
    }

    [ -e "$GF_OP_PATHS_CONFIG" ] || check_path_exists "$(grafana_env_var_value PATHS_CONFIG)"
    [ -e "$GF_OP_PATHS_DATA" ] || check_path_exists "$(grafana_env_var_value PATHS_DATA)"
    [ -e "$GF_OP_PATHS_LOGS" ] || check_path_exists "$(grafana_env_var_value PATHS_LOGS)"
    [ -e "$GF_OP_PATHS_PROVISIONING" ] || check_path_exists "$(grafana_env_var_value PATHS_PROVISIONING)"

    return "$error_code"
}

########################
# Ensure Grafana is initialized
# Globals:
#   GRAFANA_*
# Arguments:
#   None
# Returns:
#   None
#########################
grafana_initialize() {
    # Ensure compatibility with Grafana Operator
    for path_suffix in config data logs provisioning; do
        var="GF_PATHS_$(echo "$path_suffix" | tr '[:lower:]' '[:upper:]')"
        op_var="GF_OP_PATHS_$(echo "$path_suffix" | tr '[:lower:]' '[:upper:]')"
        eval grafana_val=\${$var}
        eval op_val=\${$op_var}
        if [ -e "$op_val" ] && [ "$op_val" != "$grafana_val" ]; then
            info "Ensuring $op_val points to $grafana_val"
            rm -rf "$grafana_val"
            ln -sfn "$op_val" "$grafana_val"
        fi
    done

    if am_i_root; then
        for dir in "$GF_PATHS_DATA" "$GF_PATHS_LOGS" "$GF_PATHS_PLUGINS"; do
            is_mounted_dir_empty "$dir" && configure_permissions_ownership "$dir" -d "775" -f "664" -u "$GRAFANA_DAEMON_USER"
        done
    fi

    # Install plugins in a Grafana operator-compatible environment, useful for starting the image as an init container
    if [ -d "$GF_OP_PLUGINS_INIT_DIR" ]; then
        info "Detected mounted plugins directory at '${GF_OP_PLUGINS_INIT_DIR}'. The container will exit after installing plugins as grafana-operator."
        if [ -n "$GF_INSTALL_PLUGINS" ]; then
            GF_PATHS_PLUGINS="$GF_OP_PLUGINS_INIT_DIR" grafana_install_plugins
        else
            warn "There are no plugins to install"
        fi
        return 255
    fi

    # Recover plugins installed when building the image
    if [ ! -e "$(grafana_env_var_value PATHS_PLUGINS)" ] || [ -z "$(ls -A "$(grafana_env_var_value PATHS_PLUGINS)" 2>/dev/null)" ]; then
        mkdir -p "$(grafana_env_var_value PATHS_PLUGINS)"
        if [ -e "$GRAFANA_DEFAULT_PLUGINS_DIR" ] && [ -n "$(ls -A "$GRAFANA_DEFAULT_PLUGINS_DIR" 2>/dev/null)" ]; then
            cp -r "$GRAFANA_DEFAULT_PLUGINS_DIR"/* "$(grafana_env_var_value PATHS_PLUGINS)"
        fi
    fi

    # Configure configuration file based on environment variables
    grafana_configure_from_environment_variables

    # Install plugins
    grafana_install_plugins

    # Configure Grafana feature toggles
    if ! is_empty_value "$GF_FEATURE_TOGGLES"; then
        grafana_conf_set "feature_toggles" "enable" "$GF_FEATURE_TOGGLES"
    fi

    # If using an external database, avoid nodes collision during migration
    if is_boolean_yes "$GRAFANA_MIGRATION_LOCK"; then
        grafana_migrate_db
    fi

    # Avoid exit code of previous commands to affect the result of this function
    true
}

########################
# Runs Grafana migration using a database lock to avoid collision with other Grafana nodes
# If database is locked, wait until unlocked and continue. Otherwise, run Grafana to perform migration.
# Globals:
#   GRAFANA_CFG_*
# Arguments:
#   None
# Returns:
#   None
#########################
grafana_migrate_db() {
    db_host="${GRAFANA_CFG_DATABASE_HOST:-mysql}"
    db_port="${GRAFANA_CFG_DATABASE_PORT:-3306}"
    db_name="${GRAFANA_CFG_DATABASE_NAME:-}"
    db_user="${GRAFANA_CFG_DATABASE_USER:-}"
    db_pass="${GRAFANA_CFG_DATABASE_PASSWORD:-}"

    grafana_host="${GRAFANA_CFG_SERVER_HTTP_ADDR:-localhost}"
    grafana_port="${GRAFANA_CFG_SERVER_HTTP_PORT:-3000}"
    grafana_protocol="${GRAFANA_CFG_SERVER_PROTOCOL:-http}"

    sleep_time="${GRAFANA_SLEEP_TIME:-5}"
    retries="${GRAFANA_RETRY_ATTEMPTS:-12}"

    lock_db() {
        debug_execute mysql_remote_execute_print_output "$db_host" "$db_port" "$db_name" "$db_user" "$db_pass" <<EOF
create table db_lock(
id INT PRIMARY KEY
);
EOF
    }
    release_db() {
        debug_execute mysql_remote_execute_print_output "$db_host" "$db_port" "$db_name" "$db_user" "$db_pass" <<EOF
drop table if exists db_lock;
EOF
    }
    is_db_unlocked() {
        result=$(mysql_remote_execute_print_output "$db_host" "$db_port" "$db_name" "$db_user" "$db_pass" <<EOF
show tables like 'db_lock';
EOF
)
        echo "$result" | grep -q "db_lock"
        if [ $? -eq 0 ]; then
            return 1
        else
            return 0
        fi
    }

    if lock_db; then
        info "Starting Grafana database migration"
        grafana_start_bg
        # Grafana will start listening HTTP connections once the database initialization has succeeded
        if ! retry_while "debug_execute curl --silent ${grafana_protocol}://${grafana_host}:${grafana_port}" "$retries" "$sleep_time"; then
            error "Grafana failed to start in the background. Releasing database lock before exit."
            release_db
            return 1
        fi
        grafana_stop
        release_db
        info "Grafana database migration completed. Lock released."
    else
        info "Grafana database migration in progress detected. Waiting for lock to be released before initializing Grafana"
        if ! retry_while "is_db_unlocked" "$retries" "$sleep_time"; then
            error "Failed waiting for database lock to be released. If there is no migration in progress, manually drop table 'db_lock' from the grafana database"
            return 1
        fi
    fi
}

########################
# Start Grafana in background
# Arguments:
#   None
# Returns:
#   None
#########################
grafana_start_bg() {
    cmd="grafana"
    args="server \
        --homepath=${GF_PATHS_HOME} \
        --config=${GF_PATHS_CONFIG} \
        --packaging=docker \
        --pidfile=${GRAFANA_PID_FILE} \
        cfg:default.log.mode=console \
        cfg:default.paths.data=${GF_PATHS_DATA} \
        cfg:default.paths.logs=${GF_PATHS_LOGS} \
        cfg:default.paths.plugins=${GF_PATHS_PLUGINS} \
        cfg:default.paths.provisioning=${GF_PATHS_PROVISIONING}"
    cd "$GRAFANA_BASE_DIR" || return
    info "Starting Grafana in background"
    if am_i_root; then
        set -- $args
        debug_execute run_as_user "$GRAFANA_DAEMON_USER" "$cmd" "$@" &
    else
        set -- $args
        debug_execute "$cmd" "$@" &
    fi
}

########################
# Update Grafana config file with settings provided via environment variables
# Globals:
#   GRAFANA_CFG_*
#   GF_PATHS_CONFIG
# Arguments:
#   None
# Returns:
#   None
#########################
grafana_configure_from_environment_variables() {
    # Map environment variables to config properties
    for var in $(env | grep '^GRAFANA_CFG_' | cut -d= -f1); do
        section_key_pair=$(echo "$var" | sed 's/^GRAFANA_CFG_//' | tr '[:upper:]' '[:lower:]')
        section=$(echo "$section_key_pair" | cut -d_ -f1)
        key=$(echo "$section_key_pair" | cut -d_ -f2-)
        eval value=\${$var}
        grafana_conf_set "$section" "$key" "$value"
    done
}

########################
# Update a single configuration in Grafana's config file
# Globals:
#   GF_PATHS_CONFIG
# Arguments:
#   $1 - section
#   $2 - key
#   $3 - value
# Returns:
#   None
#########################
grafana_conf_set() {
    section="${1:?missing key}"
    key="${2:?missing key}"
    value="${3:-}"
    debug "Setting configuration ${section}.${key} with value '${value}' to configuration file"
    ini-file set --section "$section" --key "$key" --value "$value" "$(grafana_env_var_value PATHS_CONFIG)"
}

########################
# Install plugins
# Globals:
#   GRAFANA_*
# Arguments:
#   None
# Returns:
#   None
#########################
grafana_install_plugins() {
    [ -z "$GF_INSTALL_PLUGINS" ] && return

    plugin_list=$(echo "$GF_INSTALL_PLUGINS" | tr ';' ',' | tr ',' ' ')
    for plugin in $plugin_list; do
        plugin_id="$plugin"
        plugin_version=""
        plugin_url=""
        install_args="--pluginsDir $(grafana_env_var_value PATHS_PLUGINS)"
        is_boolean_yes "$GF_INSTALL_PLUGINS_SKIP_TLS" && install_args="$install_args --insecure"
        case "$plugin" in
            *=*)
                plugin_id=$(echo "$plugin" | cut -d= -f1)
                plugin_url=$(echo "$plugin" | cut -d= -f2-)
                info "Installing plugin $plugin_id from URL $plugin_url"
                install_args="$install_args --pluginUrl $plugin_url"
                ;;
            *:*)
                plugin_id=$(echo "$plugin" | cut -d: -f1)
                plugin_version=$(echo "$plugin" | cut -d: -f2-)
                info "Installing plugin $plugin_id @ $plugin_version"
                ;;
            *)
                info "Installing plugin $plugin_id"
                ;;
        esac
        if [ -n "$plugin_version" ]; then
            grafana cli $install_args plugins install "$plugin_id" "$plugin_version"
        else
            grafana cli $install_args plugins install "$plugin_id"
        fi
    done
}

########################
# Check if Grafana is running
# Arguments:
#   None
# Returns:
#   Boolean
#########################
is_grafana_running() {
    pid="$(get_pid_from_file "$GRAFANA_PID_FILE")"
    if [ -n "$pid" ]; then
        is_service_running "$pid"
    else
        false
    fi
}

########################
# Check if Grafana is not running
# Arguments:
#   None
# Returns:
#   Boolean
#########################
is_grafana_not_running() {
    ! is_grafana_running
}

########################
# Stop Grafana
# Arguments:
#   None
# Returns:
#   None
#########################
grafana_stop() {
    is_grafana_not_running && return

    info "Stopping Grafana"
    stop_service_using_pid "$GRAFANA_PID_FILE"
}

########################
# Returns grafana major version
# Globals:
#   GRAFANA_BIN_DIR
# Arguments:
#   None
# Returns:
#   None
#########################
get_grafana_major_version() {
    grafana_version="$("${GRAFANA_BIN_DIR}/grafana" -v)"
    grafana_version="${grafana_version#"grafana version "}"
    major_version="$(get_sematic_version "$grafana_version" 1)"
    echo "${major_version:-0}"
}