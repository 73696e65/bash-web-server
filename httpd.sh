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

process_alive() {
	ps -A | grep "^$1 " &>/dev/null
}

kill_tree() {
	for child in $(ps -o pid= --ppid $1); do
		kill_tree $child
	done
	kill -9 $1
}

fork_with_timeout() {
    log "running $@"
    iters=0
    $@ &
    pid=$!
    log "forked CGI: $pid, waiting"
    while process_alive $pid; do 
	    if [ $iters -ge $((5*timeout)) ]; then
		    log "Killing $pid"
		    kill_tree $pid
		    break
	    fi
	    sleep 0.2
	    iters=$((iters+1))
    done
    log "Killer process on $pid exiting"
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

add_header() {
    echo "$1" | egrep -i "^$2:" &>/dev/null || echo -en "$2: $3\r\n"
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
		    if [ -x "$path" ]; then
			    response="$(fork_with_timeout "$path")"
			    if echo "$clean" | egrep '^\r*$' &>/dev/null; then
				    # log "Headers found."
				    headers="$(echo "$response" | sed -rn '1,/^\r*$/p')"
				    body="$(echo "$response" | sed -r '1,/^\r*$/d')"
			    else
				    # log "No headers found."
				    body="$response"
			    fi

			    add_header "$headers" "Content-Type"   "text/plain; charset=UTF-8"
			    add_header "$headers" "Content-Length" "$(echo "$body" | wc -c)"

			    echo "$headers"
			    echo "$body"
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
