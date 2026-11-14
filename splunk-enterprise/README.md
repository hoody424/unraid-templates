# Splunk Enterprise for Unraid

A single standalone Splunk Enterprise instance from the official
[`splunk/splunk`](https://hub.docker.com/r/splunk/splunk) image.

Template: [splunk-enterprise.xml](splunk-enterprise.xml).

## Before the first start

The container refuses to start until all three are set:

| Variable | Value |
|---|---|
| `SPLUNK_START_ARGS` | `--accept-license` |
| `SPLUNK_GENERAL_TERMS` | `--accept-sgt-current-at-splunk-com` |
| `SPLUNK_PASSWORD` | admin password, at least 8 characters |

Entering the two flags means you accept the
[Splunk General Terms](https://www.splunk.com/en_us/legal/splunk-general-terms.html)
and the Splunk Enterprise license. The password is only applied on the first
start; change it later in the web UI (Settings, Users).

The first start takes a few minutes while the image's Ansible setup runs. The
Docker tab shows `health: starting` until Splunk is ready. Then log in at
`http://SERVER-IP:8000` as `admin`.

## Version

The template uses `splunk/splunk:latest`. To pin a version, set the repository
to a tag such as `splunk/splunk:10.2.6`. Upgrading to a newer tag works in
place: Splunk migrates `etc` and `var` on the next start. Going back to an older
version is not supported, so back up both folders first.

## Ports

| Port | Use |
|---|---|
| 8000 | Splunk Web |
| 8089 | REST API / management (HTTPS) |
| 9997 | Receiving from Universal Forwarders |
| 8088 | HTTP Event Collector (HTTPS) |

If 8088 is already used on the server, change only the host side. HEC tokens
are created in Settings, Data inputs, HTTP Event Collector.

## Storage

- `etc` (`/opt/splunk/etc`): configuration, apps, users. Small.
- `var` (`/opt/splunk/var`): the indexes. Grows with the indexed data volume,
  so place it on a pool with enough room. The default retention is
  roughly 6 years or 500 GB per index; set `frozenTimePeriodInSecs` /
  `maxTotalDataSizeMB` in `indexes.conf` to limit it.

## License

Without a license file Splunk Enterprise runs as a 60-day trial with all
features, then you can switch to Splunk Free (500 MB of indexed data per day,
no users or alerts) in Settings, Licensing. Upload a purchased or developer
license there as well.

## Notes

- `--ulimit nofile=65536` is set in Extra Parameters because Splunk warns about
  a low open-file limit otherwise.
- `--stop-timeout 120` gives Splunk time to shut down cleanly; Docker's default
  10 s can cut off index writes.
- This template is not affiliated with Splunk. Splunk is a registered trademark of
  its owner.
