#!/bin/bash

pidfile=/tmp/httpd-pidfile-$$
echo "xx $pidfile"

cleanup() {
    kill -9 $(cat $pidfile)
    rm -f $pidfile
}

process_alive() {
    cpid=$1
    [ -z "$(ps -o pid= -p $cpid)" ] 
}

trap cleanup TERM
trap cleanup CHLD
trap cleanup QUIT

touch $pidfile
$@ &
cpid=$!
echo $cpid >> $pidfile

echo "last: $cpid"
while [ "process_alive $cpid" ]; do sleep 1; done

echo "volam cleanup"
cleanup
