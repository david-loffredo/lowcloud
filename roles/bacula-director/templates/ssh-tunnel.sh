#!/bin/bash
# Establishes a self-killing SSH tunnel to the given SSH server, and
# forwards the correct ports for bacula usage.
#
# Usage: sshbacula host@client [keyfile] [port]
#
# If a keyfile is not provided, it uses /etc/bacula/tunnel/tunnel.key
# If a port is not provided, it uses 9112
#
# Originally from https://wiki.bacula.org/doku.php?id=sshtunnel
# Modified by Dave to not need a .ssh config and to pass the key and
# port so we can support multiple tunnels.  Use 'accept-new' for key
# checks so no longer need to manually accept the first connection.
#
error_exit()
{
    echo "$1" 1>&2
    exit 1
}

CLIENT=$1
KEYFILE=${2:-/etc/bacula/tunnel/tunnel.key}
FDPORT=${3:-9112}

LOCAL=$(hostname -f)
SSH=/usr/bin/ssh

[ -f $KEYFILE ] || error_exit "Could not find SSH keyfile $KEYFILE"
    
echo "Starting SSH-tunnel to $CLIENT with port $FDPORT"

# -f means: go into background
# -C means: use compression
# -2 means: only use SSH2

# -R 9101:$LOCAL:9101 when client connects to remote port 9101
#    (bacula-dir), it will be forwarded to this machine.

# -R 9103:$LOCAL:9103 when client connects to remote port 9101
#    (bacula-sd), it will be forwarded to this machine.

# -L 9112:localhost:9102 when bacula-dir connects to port 9112
#    (instead of the normal 9102), it will be forwarded to the
#    client's FD. The client will think the connection was to port
#    9102 as usual

# sleep 60 is a simple command that will execute on the server and
# does nothing for 60 seconds, then it exits. This keeps ssh running
# for 60 seconds. Once we connect to the FD, that connection will keep
# ssh running even beyond the 60 seconds.  Using this approach, we do
# not need to tear down the tunnel later, it disconnects itself
# automagically.

# It is important to redirect stdout and stderr, or else bacula will
# not realize that the script has terminated.

# Use accept new to let it accept the host key first time, but fail if
# it has suddenly changed.
$SSH -fC2 -oStrictHostKeyChecking=accept-new \
     -R 9101:$LOCAL:9101 \
     -R 9103:$LOCAL:9103 \
     -L $FDPORT:localhost:9102 \
     -i $KEYFILE \
     $CLIENT sleep 20 >/dev/null 2>/dev/null
# give ssh a little time to establish the connection.
sleep 10
