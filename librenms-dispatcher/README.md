# LibreNMS Dispatcher for Unraid

Dispatcher service sidecar for an existing LibreNMS container. The official
image `librenms/librenms` does not poll devices on its own: polling and
discovery run in at least one separate dispatcher container
([LibreNMS docker docs](https://github.com/librenms/docker#dispatcher-service-container)).

Template: [librenms-dispatcher.xml](librenms-dispatcher.xml), image:
`librenms/librenms` (official), started with `SIDECAR_DISPATCHER=1`.

## Setup

1. Install and set up LibreNMS first, for example "librenms" from A75G's
   repository in Community Apps, and start it once: the dispatcher reads
   `/data/.env`, which the LibreNMS container creates.
2. Have a Redis server, for example the Redis app from Community Apps. The
   dispatcher refuses to start without `REDIS_HOST`. Set the same Redis on the
   LibreNMS container (`REDIS_HOST`, `REDIS_PORT`).
3. Install this template with:
   - **Appdata**: the same folder as the LibreNMS container's `/data`.
   - **DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD**: the same values as in
     the LibreNMS container. On the default bridge network, use the server IP
     (or another address the container can reach), not `localhost`.
   - **REDIS_HOST**: your Redis server.
   - **PUID/PGID**: the same as in the LibreNMS container.
4. Start it and check **Settings → Pollers** in LibreNMS: the dispatcher shows
   up with its node ID and hostname `librenms-dispatcher`.

## Several dispatchers

- Use the same Redis on the LibreNMS container and on every dispatcher.
- Give each dispatcher its own `DISPATCHER_NODE_ID` and change
  `--hostname=librenms-dispatcher` under Extra Parameters, so LibreNMS can tell
  them apart.

LibreNMS shows each poller under its hostname. Without a fixed hostname, the
name would change to a random container ID at every update.

## Support

- Template problems: [issues](https://github.com/hoody424/unraid-templates/issues)
- LibreNMS image: [librenms/docker](https://github.com/librenms/docker/issues)
