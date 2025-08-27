# OpenSalami ValKey v9 container image

## Note
This build contains the first Release candidate of Valkey 9.0.0! This is not to be considered production ready! https://github.com/valkey-io/valkey/releases/tag/9.0.0-rc1 

## What is ValKey?

> ValKey is an open source (BSD) high-performance key/value datastore that supports a variety of workloads such as caching, message queues, and can act as a primary database. The project is backed by the Linux Foundation, ensuring it will remain open source forever.



## TLDR
```console
docker run --name valkey ghcr.io/opensalami/salami-valkey-9:latest

#or

podman run --name valkey ghcr.io/opensalami/salami-valkey-9:latest

```


## Configuration
We can configure ValKey via Environment Variables:

| Environment variable | Default value |
|:---------------------|:--------------|
| VALKEY_DISABLE_COMMANDS | (empty) |
| VALKEY_DATABASE | valkey |
| VALKEY_AOF_ENABLED | yes |
| VALKEY_RDB_POLICY | (empty) |
| VALKEY_RDB_POLICY_DISABLED | no |
| VALKEY_PRIMARY_HOST | (empty) |
| VALKEY_PRIMARY_PORT_NUMBER | 6379 |
| VALKEY_DEFAULT_PORT_NUMBER | 6379 |
| VALKEY_PORT_NUMBER | 6379 |
| VALKEY_ALLOW_REMOTE_CONNECTIONS | yes |
| VALKEY_REPLICATION_MODE | (empty) |
| VALKEY_REPLICA_IP | (empty) |
| VALKEY_REPLICA_PORT | (empty) |
| VALKEY_EXTRA_FLAGS | (empty) |
| ALLOW_EMPTY_PASSWORD | no |
| VALKEY_PASSWORD | (empty) |
| VALKEY_PRIMARY_PASSWORD | (empty) |
| VALKEY_ACLFILE | (empty) |
| VALKEY_IO_THREADS_DO_READS | (empty) |
| VALKEY_IO_THREADS | (empty) |
| VALKEY_TLS_ENABLED | no |
| VALKEY_TLS_PORT_NUMBER | 6379 |
| VALKEY_TLS_CERT_FILE | (empty) |
| VALKEY_TLS_CA_DIR | (empty) |
| VALKEY_TLS_KEY_FILE | (empty) |
| VALKEY_TLS_KEY_FILE_PASS | (empty) |
| VALKEY_TLS_CA_FILE | (empty) |
| VALKEY_TLS_DH_PARAMS_FILE | (empty) |
| VALKEY_TLS_AUTH_CLIENTS | yes |
| VALKEY_SENTINEL_PRIMARY_NAME | (empty) |
| VALKEY_SENTINEL_HOST | (empty) |
| VALKEY_SENTINEL_PORT_NUMBER | (empty) |

Note: VALKEY_PORT_NUMBER defaults to VALKEY_DEFAULT_PORT_NUMBER (6379). VALKEY_TLS_PORT_NUMBER defaults to VALKEY_TLS_PORT (if set) or 6379.



