#!/bin/bash

pidfile=/tmp/httpd-pidfile-$$

cleanup() {
    kill -9 $(cat $pidfile) 2> /dev/null
    rm -f $pidfile
}

trap cleanup TERM
trap cleanup CHLD
trap cleanup QUIT

touch $pidfile
$@ &
cpid=$!
echo $cpid >> $pidfile
wait $cpid

cleanup
