#!/usr/bin/dumb-init /bin/sh
set -e

# Note above that we run dumb-init as PID 1 in order to reap zombie processes
# as well as forward signals to all processes in its session. Normally, sh
# wouldn't do either of these functions so we'd leak zombies as well as do
# unclean termination of all our sub-processes.

# Allow setting VAULT_REDIRECT_ADDR and VAULT_CLUSTER_ADDR using an interface
# name instead of an IP address. The interface name is specified using
# VAULT_REDIRECT_INTERFACE and VAULT_CLUSTER_INTERFACE environment variables. If
# VAULT_*_ADDR is also set, the resulting URI will combine the protocol and port
# number with the IP of the named interface.
get_addr () {
    IF_NAME=$1
    ip addr show dev $IF_NAME | awk -v uri=$2 '/\s*inet\s/ { \
      ip=gensub(/(.+)\/.+/, "\\1", "g", $2); \
      print gensub(/^(.+:\/\/).+(:.+)$/, "\\1" ip "\\2", "g", uri)}'
}


# If the user is trying to run Caddy directly with some arguments, then
# pass them to Caddy.
if [ "${1:0:1}" = '-' ]; then
    set -- caddy "$@"
fi

# If we are running Vault, make sure it executes as the proper user.
if [ "$1" = 'caddy' ]; then
    # If the config dir is bind mounted then chown it
    if [ "$(stat -c %u /caddy/config)" != "$(id -u caddy)" ]; then
        chown -R caddy:caddy /caddy/config || echo "Could not chown /caddy/config (may not have appropriate permissions)"
    fi

    # If the logs dir is bind mounted then chown it
    if [ "$(stat -c %u /caddy/logs)" != "$(id -u caddy)" ]; then
        chown -R caddy:caddy /caddy/logs
    fi

    if [ -z "$SKIP_SETCAP" ]; then
        setcap cap_ipc_lock=+ep $(readlink -f $(which caddy))

        # In the case caddy has been started in a container without IPC_LOCK privileges
        if ! caddy -version 1>/dev/null 2>/dev/null; then
            >&2 echo "Couldn't start caddy with IPC_LOCK. Disabling IPC_LOCK, please use --privileged or --cap-add IPC_LOCK"
            setcap -r $(readlink -f $(which caddy))
        fi
    fi

    set -- gosu caddy "$@"
fi

exec "$@"
