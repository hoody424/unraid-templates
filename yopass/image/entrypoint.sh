#!/bin/bash
# Runs the built-in Memcached (RAM only, nothing is written to disk) next to
# yopass-server. With DATABASE=redis or MEMCACHED pointing at another host,
# only yopass-server runs. If either process exits, the container stops.
set -u

# Empty template fields mean the defaults.
export MEMCACHED=${MEMCACHED:-127.0.0.1:11211}
MEMCACHED_MEMORY=${MEMCACHED_MEMORY:-64}

builtin=false
if [ "${DATABASE:-memcached}" = memcached ]; then
  case "$MEMCACHED" in
    127.0.0.1:* | localhost:*) builtin=true ;;
  esac
fi
$builtin || exec yopass-server "$@"

port=${MEMCACHED##*:}
memcached --listen=127.0.0.1 --port="$port" --udp-port=0 \
  --memory-limit="$MEMCACHED_MEMORY" --max-item-size=4m &
memcached_pid=$!

for _ in $(seq 50); do
  (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null && break
  kill -0 "$memcached_pid" 2>/dev/null || { wait "$memcached_pid"; exit $?; }
  sleep 0.1
done

yopass-server "$@" &
yopass_pid=$!

trap 'kill -TERM "$memcached_pid" "$yopass_pid" 2>/dev/null' TERM INT
wait -n
status=$?
kill -TERM "$memcached_pid" "$yopass_pid" 2>/dev/null
wait
exit "$status"
