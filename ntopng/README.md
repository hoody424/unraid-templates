# ntopng for Unraid

[ntopng](https://www.ntop.org/products/traffic-analysis/ntop/) is a web-based
network traffic analysis tool. Template: [ntopng.xml](ntopng.xml), image:
`ntop/ntopng` (official, Community edition without a license).

## Redis is required

ntopng keeps its users, passwords and settings in Redis. The official image
starts its own Redis inside the container, but that Redis runs as an
unprivileged user and cannot save into an Unraid appdata folder. Without an
external Redis, every restart or update resets ntopng to admin/admin with
default settings.

So run a Redis container first, for example the Redis app from Community
Apps, publishing port 6379. ntopng reaches it as `127.0.0.1:6379` because it
uses host networking. The `@3` in `-r 127.0.0.1:6379@3` selects Redis database
3; pick a number no other app uses (many apps use 0 and 1).

## Options

Everything is set in **ntopng options** (variable `NTOP_CONFIG`):

| Option | Default | Meaning |
|---|---|---|
| `-i` | `br0` | Interface to monitor. `br0` on most Unraid servers; `eth0` or `bond0` without bridging. Repeat `-i` for several. |
| `-w` | `3000` | Web port. With host networking it must be free on the server; change the WebUI link too. |
| `-r` | `127.0.0.1:6379@3` | Redis `host:port@database`. |
| `-m` | private ranges | Local networks, comma-separated, no spaces or quotes. |

Don't use quotes in the options: the image passes them on literally.

The template adds `--cap-add=NET_ADMIN --cap-add=NET_RAW`. Without them
ntopng logs "Unable to enable capabilities".

## First login

Open `http://<server>:3000`, log in as `admin` / `admin` and set a new
password when asked.

## Support

- Template problems: [issues](https://github.com/hoody424/unraid-templates/issues)
- ntopng itself: [ntop/ntopng](https://github.com/ntop/ntopng/issues)
