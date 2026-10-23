#!/bin/sh
# First start: write a default config to /config. Later starts keep the
# user's file. Then run as PUID:PGID (Unraid default nobody:users).
set -eu

conf=/config/config.toml
if [ ! -f "$conf" ]; then
  echo "No $conf yet, writing the default config"
  cp /usr/share/apt-cacher-ultra/config.toml.default "$conf"
fi

# Optional admin password: written as a bcrypt htpasswd file on every start,
# so changing the variable and restarting is enough.
htpasswd_file=/config/admin.htpasswd
if [ -n "${ADMIN_PASSWORD:-}" ]; then
  htpasswd -cbB "$htpasswd_file" "${ADMIN_USER:-admin}" "$ADMIN_PASSWORD" 2>/dev/null
  chmod 0640 "$htpasswd_file"
  sed -i "s|^htpasswd_file *=.*|htpasswd_file = \"$htpasswd_file\"|" "$conf"
else
  rm -f "$htpasswd_file"
  sed -i 's|^htpasswd_file *=.*|htpasswd_file = ""|' "$conf"
fi

chown -R "$PUID:$PGID" /cache
chown "$PUID:$PGID" /config "$conf"
[ -f "$htpasswd_file" ] && chown "$PUID:$PGID" "$htpasswd_file"

exec su-exec "$PUID:$PGID" /usr/local/bin/apt-cacher-ultra -config "$conf" "$@"
