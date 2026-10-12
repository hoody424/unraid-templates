# Yopass for Unraid

[Yopass](https://github.com/jhaals/yopass) shares passwords, secrets and small
files through links that expire and can be opened only once. The recipient
needs no account, which makes it handy for sending a password to someone
outside your organisation.

Secrets are encrypted in the browser before upload. The key is part of the
link (after `#`, which browsers never send to the server), so the server only
stores ciphertext.

Template: [yopass.xml](yopass.xml), image: `ghcr.io/hoody424/yopass` (amd64),
built from [image/](image/).

## What the image adds to the official one

- **Built-in Memcached:** one container instead of two. Secrets live in RAM
  only: nothing is written to disk, and a restart or update deletes all open
  secrets. There is no appdata folder and nothing to back up.
- **Works under a path:** the official web UI only works at the root of a
  domain. This image builds it with relative URLs, so
  `https://example.com/yopass/` works as well as `https://yopass.example.com/`,
  and the links it generates keep the path.
- **HTTPS notice:** without HTTPS the official UI stays blank. This one
  explains why.
- **Updates:** the image is rebuilt every week with the newest Yopass release
  and Debian updates, and tagged `latest` plus the Yopass version
  (for example `15.0.0`).

## Setup

1. Install the template. The defaults work as they are.
2. Put Yopass behind your reverse proxy with HTTPS, pointing at
   `http://<server>:1337`. Browsers only allow the encryption on https://
   pages (or on localhost), so `http://<server-ip>:1337` (the WebUI button)
   only shows a notice.
   - **Own domain:** proxy `https://yopass.example.com/` to port 1337.
   - **Under a path:** proxy `https://example.com/yopass/` to port 1337 and
     strip the `/yopass` prefix. Redirect `/yopass` to `/yopass/`: the
     trailing slash is required.
3. Open the https:// address, paste a secret, and send the link.

## Sending secrets safely

- **Use two channels:** send the link by mail and say on the phone what it is
  for. With **Hide one-click link** (advanced view) the result page offers only
  the short link and the key, to send separately.
- **Mail scanners:** some mail filters open every link to check it. Yopass
  shows a "Reveal" button before it downloads the secret, so a scanner that
  only loads the page does not use up a one-time link. If the recipient still
  gets "secret does not exist", treat the password as exposed and change it.
- **One-time only:** set it to `true` to stop anyone from creating secrets that
  can be opened more than once.

## Public instances

If the server is reachable from the internet, anyone can create secrets, as on
the upstream demo. The template limits size (10 KB text, 512 KB files),
Memcached memory (64 MB) and lifetime (one week at most). Add rate limiting
at your reverse proxy if you want more. **Imprint URL** and **Privacy notice
URL** (advanced view) add footer links, which some countries require for
public sites.

## External Redis or Memcached

Advanced view: set **Database** to `redis` and a **Redis URL**, or set
**Memcached address** to another `host:port`. The built-in Memcached then
does not start. Note that Redis may write its data to disk.
