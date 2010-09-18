#!/bin/bash

pidfile=$1
echo "xx $pidfile"
shift

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
echo $! >> $pidfile

echo "last: $!"
while [ "process_alive $!" ]; do sleep 1; done

echo "volam cleanup"
echo "volam cleanup"
cleanup
