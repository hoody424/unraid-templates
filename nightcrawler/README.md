# nightcrawler for Unraid

[nightcrawler](https://github.com/hoody424/nightcrawler) watches marketplaces
and shops for new, used and refurbished products, filters listings by real
specs (Geizhals-style), tracks prices and sends notifications. Optional AI
features run on your Claude Pro/Max subscription.

Template: [nightcrawler.xml](nightcrawler.xml), image:
`ghcr.io/hoody424/nightcrawler` (amd64 + arm64).

## First start

1. Install the template; the defaults work as they are.
2. Open the web UI (`http://<server>:8080`). The first start sets up a demo
   source (webscraper.io's public test shop) and a few watchlists, and the
   first crawl starts within seconds.
3. Create your own watchlists and sources in the web UI. Everything is stored
   in the **Data** folder (`/mnt/user/appdata/nightcrawler`): one SQLite
   database plus the Claude login. Back up that folder.

If the server is reachable from outside your network, set **Username** and
**Password** (HTTP basic auth) and put nightcrawler behind a reverse proxy
with HTTPS.

## AI with your Claude subscription

1. Open the container console (Docker tab > nightcrawler icon > Console) and
   run `claude setup-token`. It shows a link: open it, log in to your Claude
   account, and paste the code back into the console.
2. Copy the printed `sk-ant-oat...` token into **Claude subscription token**
   in the template, or into **Settings > AI** in the web UI.
3. Click **Test connection** in Settings > AI.

AI calls count towards your plan's usage limits; **Max AI calls / hour**
(default 60) caps them. A subscription is for your own use; if other people
use your nightcrawler, set an **Anthropic API key** (advanced view) instead.

## eBay

Create a free *Production* keyset at
[developer.ebay.com](https://developer.ebay.com/my/keys) and enter the App ID
as **eBay client ID** and the Cert ID as **eBay client secret**.
**eBay enabled** only switches the source on during the very first start;
after that, enable it on the Sources page. Pick the marketplace (EBAY_DE,
EBAY_US, ...) there too.

eBay keeps a new Production keyset disabled until you handle Marketplace
Account Deletion (subscribe or opt out), see
[eBay setup](https://github.com/hoody424/nightcrawler#ebay-setup).

## Notifications

Settings > Notifications takes one [Apprise URL](https://github.com/caronc/apprise/wiki)
per line, for example `ntfy://my-topic` or `tgram://bot_token/chat_id`.

## PUID / PGID

The container starts as root, gives the Data folder to `PUID`:`PGID`
(Unraid default `99`:`100`, user nobody, group users) and then runs as that
user. Changing the values later is fine; ownership is fixed at the next start.

## Support

- nightcrawler itself and this template: [hoody424/nightcrawler issues](https://github.com/hoody424/nightcrawler/issues)
