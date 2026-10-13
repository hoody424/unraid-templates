# FluxMQ for Unraid

[FluxMQ](https://github.com/absmach/fluxmq) is a message broker in a single Go
binary: MQTT 3.1.1 and 5.0 (TCP and WebSocket), AMQP 1.0, AMQP 0.9.1, durable
queues with consumer groups, BadgerDB storage. The upstream project calls
itself experimental.

Templates (official images by Abstract Machines, amd64 + arm64):

| Template | Image |
|---|---|
| [fluxmq.xml](fluxmq.xml) | `ghcr.io/absmach/fluxmq` |
| [fluxmq-dashboard.xml](fluxmq-dashboard.xml) | `ghcr.io/absmach/fluxmq-dashboard` |

## Ports

| Port | Protocol |
|---|---|
| 1883 | MQTT 3.1.1 |
| 1884 | MQTT 5.0 (FluxMQ serves each MQTT version on its own port) |
| 8083 / 8084 | MQTT 3.1.1 / 5.0 over WebSocket, path `/mqtt` |
| 5672 | AMQP 1.0 |
| 5682 | AMQP 0.9.1 |
| 8081 | `/health`, `/ready` |
| 8082 | Admin API for the dashboard, **no authentication** |

## First start

The template works without a config file. The appdata folder is mounted at
`/tmp/fluxmq`, which is where FluxMQ keeps its data by default, and the
container runs as `99:100` (nobody:users).

**Retained messages:** with the defaults (clustering off) the current FluxMQ
build stores retained messages but never sends them to new subscribers.
Single-node cluster mode works. To use it, copy [config.yaml](config.yaml)
to the appdata folder and restart the container:

```sh
wget -O /mnt/user/appdata/fluxmq/config.yaml \
  https://raw.githubusercontent.com/hoody424/unraid-templates/main/fluxmq/config.yaml
chown 99:100 /mnt/user/appdata/fluxmq/config.yaml
```

The container log should then show `Running in cluster mode` and
`Node became cluster leader`. The embedded etcd and the node transport only
listen on loopback.

## Config file

`/mnt/user/appdata/fluxmq/config.yaml` is read on start; every key you leave
out keeps its default. See the
[configuration reference](https://www.absmach.eu/docs/fluxmq/reference/configuration-reference).
Keep all paths under `/tmp/fluxmq`, otherwise the data ends up inside the
container and is lost on the next update. Many settings can be reloaded
without a restart: `docker kill -s HUP FluxMQ`.

## Security

- FluxMQ has no user/password list. Clients connect anonymously unless you set
  up an external auth service (`auth.external`, see
  [Security](https://www.absmach.eu/docs/fluxmq/configuration/security)).
  Only expose the broker to networks you trust.
- The admin API (8082) lets anyone who reaches it list all sessions, manage
  queues and reload the config. Remove the port mapping if you don't use the
  dashboard, and never forward it.
- TLS listeners (`server.mqtt.tcp.tls`, `server.mqtt.websocket.tls`) need
  certificate files in the appdata folder; see the
  [examples](https://github.com/absmach/fluxmq/tree/main/examples).

## Dashboard

FluxMQ-Dashboard shows live traffic, sessions, subscriptions and broker info.
It only reads and has no login.

- **Bridge (default):** set *FluxMQ admin API* to
  `http://<server IP>:8082`. Open `http://<server IP>:3001/dashboard`.
- **Sharing FluxMQ's network:** set *Network Type* to *Container: FluxMQ* and
  *FluxMQ admin API* to `http://127.0.0.1:8082`. The dashboard is then on
  FluxMQ's IP, port 3001 (useful when FluxMQ has its own IP on a custom
  network), and you can add `admin_api_addr: "127.0.0.1:8082"` to config.yaml
  so the admin API is not reachable from the network at all. Restart the
  dashboard after every restart or update of FluxMQ: Docker does not reconnect
  it to the new network.
