#!/bin/bash 

# usage: ncat -l 8080 -e ./httpd.sh

### global variables that contain the configuration options ###
basedir=$PWD/webroot
cgi_bash="true"
cgi_perl="true"
timeout=4
###############################################################

log() {
	# use tail -f /tmp/httpd.log
	echo $@ >> /tmp/httpd.log
}

cleanup() {
    log "Cleaning up $pidfile, killing $(cat $pidfile)"
    kill -9 $(cat $pidfile) 2> /dev/null
    rm -f $pidfile
    exit 0
}

wrapper() {
	pidfile=/tmp/httpd-pidfile-$$
	log "launching wrapper $pidfile"

	trap cleanup HUP
	trap cleanup TERM
	trap cleanup CHLD
	trap cleanup QUIT
	trap cleanup ALRM

	touch $pidfile
	$@ &
	cpid=$!
	log "CGI script PID: $cpid (written to $pidfile)"
	echo $cpid > $pidfile
	wait $cpid

	cleanup
}

wrapper_alive() {
	if [ -e "/tmp/httpd-pidfile-$1" ]; then
		return 0
	else
		return 1
	fi
}

launch_killer_process() {
    pid=$1
    iters=0
    log "Launching killer process (pid $$) on $pid"
    while wrapper_alive $pid; do 
	    if [ $iters -ge $((5*timeout)) ]; then
		    log "Killing"
		    kill -SIGHUP $pid
		    echo "Process killed."
		    break
	    fi
	    sleep 0.2
	    iters=$((iters+1))
    done
    log "Killer process on $pid exiting"
}

fork_with_timeout() {
    wrapper $@ &
    pid=$!
    log "wrapper pid is $pid"
    touch "/tmp/httpd-pidfile-$pid"
    launch_killer_process $pid &
}

upperx() {
    echo "$*" | tr 'a-z' 'A-Z' | tr -d '\r'
}

serve() {
    if [ ! -e "$(echo "${basedir}""${url}" | sed 's#%20#\ #g')" ]; then response "404 Not found" "$basedir$url"
    else
        if [ ! -r "$(echo "${basedir}""${url}" |   sed 's#%20#\ #g')" ]; then response "403 Forbidden" "$basedir$url"
            else
            response "200 OK" "${basedir}""${url}"
        fi
    fi
}

get_mime() {
	file="$1"
	mime=$(file --mime-type "$file" | sed 's#.*:\ ##')
	if [ $mime = "application/x-directory" -o $mime = "application/x-empty" ]; then mime="text/html"; fi
	echo $mime
}

response() {
	code="$1"
        path="$(echo $2 | sed 's#%20#\ #g')"
        echo "$(upperx $http_version) $code";
	
	case "$code" in
		200*)
	        mime=$(get_mime "$path")
		if [ -d "$path" ]; then 
	            echo -e "Content-Type: "$mime"; charset=utf-8\n"
                    echo "<table><tr><th>"
                    IFS=$(echo -en "\n\b")
                    for file in $(ls -1aF "$path" | grep -v "^./$" | sed 's#\*##g'); do
                        echo "<tr><td valign="top"><a href=\"$file\">$file</a></td>"
                    done
                    unset IFS
                    echo "</th></tr></table>"
                else
                    if [ $mime = "text/x-shellscript" -a $cgi_bash = "true" -a -x "$path" ]; then
                        echo -e "Content-Type: text/html; charset=utf-8\n" 
                        fork_with_timeout "$path" && echo -e "\r"
                    else
                        if [ $mime = "text/x-perl" -a $cgi_perl = "true" -a -x "$path" ]; then 
                            echo -e "Content-Type: text/html; charset=utf-8\n" 
                            fork_with_timeout "$path" && echo -e "\r"
                        else
                            echo -e "Content-Type: $mime; charset=utf-8\n" && cat "$path" && echo -e "\r"
                        fi
                    fi
                fi
		;;

		403*)
### 403 forbidden ###
cat << 403
Content-Type:text/html; charset=utf-8

<html><head>
<title>403 Forbidden</title>
</head><body>
<h1>Forbidden</h1>
<p>You don't have permission to access $url
on this server.</p>
</body></html>
403
		;;
            	404*)
### 404 not found ###
cat << 404
Content-Type:text/html; charset=utf-8

<html><head>
<title>404 Not Found</title>
</head><body>
<h1>Not Found</h1>
<p>The requested URL $url was not found on this server.</p>
</body></html>
404
		;;
	esac
}

read method url http_version
read # new line

case "$(upperx $http_version)" in
  HTTP/1.0)
  ;;

  HTTP/1.1)
    read host
  ;;

  *)
    echo "Method not implemented" 
    exit 1
  ;;
esac

case "$(upperx $method)" in
  GET)
    serve
  ;;

  POST) 
    echo "POST method not implemented yet"
    exit 1
  ;;

  *)
  ;;
esac
