# apt-cacher-ultra for Unraid

[apt-cacher-ultra](https://github.com/linsomniac/apt-cacher-ultra) is a
caching proxy for Debian and Ubuntu packages. The first machine that runs
`apt install` or `apt upgrade` downloads the files from the internet; all
others get them from your server. It is a maintained replacement for
apt-cacher-ng: same port 3142, same proxy mode and the same `http://HTTPS///`
URL convention, so clients set up for apt-cacher-ng keep working.

- Every file is checked against the repository's signed index.
- While a mirror is down or slow, cached packages and indexes are still served.
- Status page and Prometheus metrics on port 6789.

Template: [apt-cacher-ultra.xml](apt-cacher-ultra.xml), image:
`ghcr.io/hoody424/apt-cacher-ultra` (amd64), built from [image/](image/).
Upstream publishes release binaries but no image. This one downloads the
release binary, checks its SHA256 and adds a small start script. It is
rebuilt every week with the newest release and Alpine updates, and tagged
`latest` plus the version (for example `1.0.2`).

## Setup

1. Install the template. The defaults work as they are.
2. On every Debian/Ubuntu client, create `/etc/apt/apt.conf.d/01proxy`:

   ```
   Acquire::http::Proxy "http://SERVER-IP:3142";
   ```

   Laptops that are not always on your network can use
   [auto-apt-proxy](https://packages.debian.org/stable/auto-apt-proxy)
   instead, which falls back to a direct connection.
3. Run `apt update` on a client. The status page `http://SERVER-IP:6789/`
   shows the repositories it has seen.

## HTTPS repositories

Downloads from `https://` sources are not cached; they go straight to the
repository. To cache one, change its sources line from `https://host/path`
to `http://HTTPS///host/path`. apt-cacher-ultra fetches it over HTTPS, and apt
still checks the repository signature. Example for a `.list` file:

```
deb [signed-by=/usr/share/keyrings/example.gpg] http://HTTPS///repo.example.com/debian stable main
```

## Configuration

On the first start the container writes `/config/config.toml`
(appdata `config/`). Edit it and restart the container. All options are in the
[upstream reference](https://github.com/linsomniac/apt-cacher-ultra/blob/main/docs/configuration.md).
Settings worth looking at:

- **`allowed_host_regex`:** by default any repository host is allowed. Anyone
  who can reach port 3142 can then download through your server. List only
  the mirrors you use, for example
  `['^deb\.debian\.org$', '^security\.debian\.org$', '^([a-z]{2}\.)?archive\.ubuntu\.com$', '^security\.ubuntu\.com$']`.
- **`deny_target_ranges`:** empty by default, so mirrors on your LAN work. If
  you use only public mirrors, block the private ranges (example in the file).
- **Admin password:** set it in the template. The container writes the login
  file on each start; the status page then asks for it. Without one, anyone
  who can reach port 6789 sees which packages your machines install.
- **`tls_mitm`:** off. When on, it caches HTTPS by acting as the repository
  itself, which needs its CA certificate (in `/cache/ca`) installed on every
  client. `http://HTTPS///` does not need that.

The cache cleans itself: package versions nobody has asked for in a week are
removed once newer ones exist (`[gc]` and `[retention]` in the reference).

## Moving from apt-cacher-ng

Stop the apt-cacher-ng container and install this one on the same port 3142.
Clients need no change. `Remap-` lines from `acng.conf` are not needed:
`http://HTTPS///` sources work as before. The old cache can't be imported;
apt-cacher-ultra fills a new one as clients ask for packages.

## Changes for existing installs

Unraid does not update installed templates. New template versions are listed
under `<Changes>` in the template and here.

- 2026-10-23: first release (apt-cacher-ultra 1.0.2).
