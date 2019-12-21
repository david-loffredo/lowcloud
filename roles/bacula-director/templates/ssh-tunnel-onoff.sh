#!/bin/sh
# script for creating / stopping a ssh-tunnel to a backupclient
# Stephan Holl<sholl@gmx.net>
# Modified by Joshua Kugler <joshua.kugler@uaf.edu>
# from https://github.com/naszaklasa/bacula/
#

# Bacula-dir runs as user bacula, but with root's environment. We need
# to trick it into running actually looking for the .ssh directory in
# the right place.
USER=bacula
HOME=$(grep "^$USER:" /etc/passwd | cut -d : -f 6)
CLIENT=$1
KEYFILE=${2:-/etc/bacula/tunnel/tunnel.key}
FDPORT=${3:-9112}

LOCAL=$(hostname -f)
SSH=/usr/bin/ssh

error_exit()
{
    echo "$1" 1>&2
    exit 1
}

case "$1" in
 start)
    # create ssh-tunnel 
        echo "Starting SSH-tunnel to $CLIENT..."
        $SSH -fnCN2 -o PreferredAuthentications=publickey \
	     -i /usr/local/bacula/ssh/id_dsa -l $USER -R 9101:$LOCAL:9101 -R 9103:$LOCAL:9103 $CLIENT > /dev/null 2> /dev/null
        exit $?
        ;;

 stop)
        # remove tunnel 
        echo "Stopping SSH-tunnel to $CLIENT..."
        # find PID killem
        PID=`ps ax | grep "ssh -fnCN2 -o PreferredAuthentications=publickey -i /usr/local/bacula/ssh/id_dsa" | grep "$CLIENT" | awk '{ print $1 }'`
        kill $PID
        exit $?
        ;;
 *)
        #  usage:
        echo "             "
        echo "      Start SSH-tunnel to client-host"
        echo "      to bacula-director and storage-daemon"
        echo "            "
        echo "      USAGE:"
        echo "      ssh-tunnel.sh {start|stop} client.fqdn"
        echo ""
        exit 1
        ;;
esac
