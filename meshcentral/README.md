# MeshCentral for Unraid

MeshCentral is a self-hosted remote management server: remote desktop, terminal,
file transfer and power control for Windows, Linux and macOS devices through a
small agent.

Template: [meshcentral.xml](meshcentral.xml), image: `ghcr.io/ylianst/meshcentral` (official).

## First start

1. Set **Server name (HOSTNAME)** to the DNS name or IP that agents and browsers
   use. It becomes the server certificate name and is built into every agent
   installer, so set it before you install agents.
2. Keep the **HTTPS port** (host side), its container port and **PORT** the same
   number (default 8443). MeshCentral tells the agents to connect to the port
   it listens on, so a different host port breaks the agents.
3. Start the container and open `https://<server>:8443`. The browser warns about
   the self-signed certificate. The first account you create becomes the
   administrator.

## config.json

The container keeps its configuration in `appdata/meshcentral/data/config.json`.

- `DYNAMIC_CONFIG=true` (template default): at every start the template values
  (HOSTNAME, PORT, ALLOW_NEW_ACCOUNTS, WEBRTC, reverse proxy, database, ...)
  are written into config.json. Keys the template does not cover (for example
  aliasPort, title, autoBackup) are kept.
- `DYNAMIC_CONFIG=false`: config.json is created once from the image template
  and then left alone; the template variables have no effect any more.

## Own IP (br0 / VLAN)

With a custom network the container gets its own IP and no port mapping is
used. Set `PORT=443` and edit the HTTPS container port to 443.

## Behind a reverse proxy

Agents must connect to the port the proxy publishes, so:

- `PORT` = the proxy's public HTTPS port (usually 443); edit the HTTPS
  container port to the same number. The host port can be anything; point the
  proxy at it.
- `REVERSE_PROXY` = the public name, e.g. `mesh.example.com`, and
  `REVERSE_PROXY_TLS_PORT=443`. MeshCentral loads the proxy certificate from
  there so the agents accept it.
- If the proxy talks plain HTTP to MeshCentral, set `TLS_OFFLOAD` to the
  proxy's IP. Leave it empty otherwise: any value, even `false`, switches
  MeshCentral to plain HTTP.
- The proxy must pass WebSockets.

More: [MeshCentral documentation](https://ylianst.github.io/MeshCentral/), section on reverse proxies.

## Intel AMT

For Intel AMT CIRA add a port mapping 4433:4433 (host and container the same).

## Database

The built-in NeDB database is fine for small setups. For many devices use
MongoDB, MariaDB or PostgreSQL through the `USE_*` variables (advanced view).

## Support

- Template problems: [issues](https://github.com/hoody424/unraid-templates/issues)
- MeshCentral itself: [Ylianst/MeshCentral](https://github.com/Ylianst/MeshCentral/issues)
