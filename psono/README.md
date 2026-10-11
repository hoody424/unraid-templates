# psono (server) for Unraid

Psono is a self-hosted password manager for teams. This template runs the
server (the API) from the official image `psono/psono-server`. The Psono
browser extensions, apps and web client connect to it.

Template: [psono.xml](psono.xml)

## Before the first start

1. **PostgreSQL.** Any PostgreSQL container works, for example `postgres:18-alpine`
   with `POSTGRES_USER=psono`, `POSTGRES_PASSWORD=...` and port 5432. With your
   own database server, create the database and user as in the
   [Psono database guide](https://doc.psono.com/admin/installation/install-postgres-db.html)
   (including the `ltree` and `pgcrypto` extensions).
2. **Keys.** Generate the server keys once, on the Unraid console:

   ```sh
   docker run --rm psono/psono-server:latest python3 ./psono/generateserverkeys.py
   ```

   Keep `ADMIN_RECOVERY_PRIVATE_KEY` offline. It does not go into settings.yaml.
3. **settings.yaml.** Create `/mnt/user/appdata/psono/settings.yaml` from the
   example in the [Psono CE guide](https://doc.psono.com/admin/installation/install-psono-ce.html)
   and paste in the generated keys. The container reads it as
   `/root/.psono_server/settings.yaml`. Points that differ on Unraid:
   - `DATABASES` → `HOST`: the Unraid server's IP (or the database container's
     name if both are on the same custom Docker network). `localhost` would be
     the psono container itself.
   - `HOST_URL`: the URL clients use to reach this server, for example
     `https://psono.example.com/server` behind your reverse proxy.
   - `NUM_PROXIES`: the number of reverse proxies in front of the container
     (1 for a single proxy; the guide's 2 is for the combo image).
4. Start the container. It runs the database migrations itself, then listens
   on the API port. `http://<server>:10100/info/` shows the version when it
   works.

Most settings can also be passed as environment variables with the prefix
`PSONO_` (for example `PSONO_DEBUG=false`). They override settings.yaml.

## Updating from the old template

Earlier versions of this template mapped the config folder to `/var/lib/psono`,
which the current image does not read. Edit the container and change the
container path of **Config folder** to `/root/.psono_server`. The default
host port also moved from 80 to 10100. Existing containers keep their port
until you change it.
