"""Health check for the Unraid templates in this repository.

Errors (exit 1): broken XML, missing required fields, wrong TemplateURL,
port entries without a container port, an image tag the registry does not
know (or a private image), a dead icon URL.
Warnings: unreachable Support/Project pages, a missing <Date>, a Docker Hub
tag that has not been pushed for a year (upstream may be abandoned).

Uses only the Python standard library, so it runs on any runner or locally:
    python3 .github/scripts/check_templates.py
"""
import datetime
import json
import os
import re
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPO = os.environ.get("GITHUB_REPOSITORY", "hoody424/unraid-templates")
RAW = f"https://raw.githubusercontent.com/{REPO}/main"
REQUIRED = ["Name", "Repository", "Overview", "Category", "Icon", "Support", "TemplateURL"]
STALE_DAYS = 365
UA = "unraid-templates-check (+https://github.com/%s)" % REPO
MANIFEST_TYPES = ", ".join([
    "application/vnd.oci.image.index.v1+json",
    "application/vnd.docker.distribution.manifest.list.v2+json",
    "application/vnd.oci.image.manifest.v1+json",
    "application/vnd.docker.distribution.manifest.v2+json",
])

errors, warnings, rows = [], [], []


def error(file, msg):
    errors.append((file, msg))


def warn(file, msg):
    warnings.append((file, msg))


def request(url, method="GET", headers=None, timeout=30):
    req = urllib.request.Request(url, method=method, headers={"User-Agent": UA, **(headers or {})})
    return urllib.request.urlopen(req, timeout=timeout)


def url_status(url):
    """HTTP status of url (GET, redirects followed), or the exception text."""
    try:
        with request(url) as r:
            return r.status, r.headers.get("Content-Type", "")
    except urllib.error.HTTPError as e:
        return e.code, ""
    except Exception as e:  # DNS, TLS, timeout
        return str(e), ""


def split_image(ref):
    """'ghcr.io/a/b:tag' -> (registry, repo, tag); Docker Hub names get registry-1.docker.io."""
    name, tag = ref, "latest"
    if "@" in ref:
        name, tag = ref.split("@", 1)
    elif ":" in ref.rsplit("/", 1)[-1]:
        name, tag = ref.rsplit(":", 1)
    first = name.split("/", 1)[0]
    if "/" in name and ("." in first or ":" in first or first == "localhost"):
        registry, repo = name.split("/", 1)
    else:
        registry, repo = "registry-1.docker.io", name if "/" in name else f"library/{name}"
    return registry, repo, tag


def manifest_status(registry, repo, tag):
    """HEAD the manifest anonymously (HEAD does not count against Docker Hub pull limits)."""
    url = f"https://{registry}/v2/{repo}/manifests/{tag}"
    headers = {"Accept": MANIFEST_TYPES}
    for _ in range(2):
        try:
            with request(url, "HEAD", headers) as r:
                return r.status
        except urllib.error.HTTPError as e:
            challenge = e.headers.get("WWW-Authenticate", "")
            if e.code != 401 or "Authorization" in headers or not challenge.lower().startswith("bearer"):
                return e.code
            p = dict(re.findall(r'(\w+)="([^"]*)"', challenge))
            token_url = f"{p['realm']}?service={p.get('service', '')}&scope=repository:{repo}:pull"
            try:
                with request(token_url) as r:
                    body = json.load(r)
            except urllib.error.HTTPError as te:
                return te.code
            headers["Authorization"] = "Bearer " + (body.get("token") or body.get("access_token", ""))
        except Exception as e:
            return str(e)
    return "no answer"


def dockerhub_last_push(repo, tag):
    try:
        ns, name = repo.split("/", 1)
        with request(f"https://hub.docker.com/v2/namespaces/{ns}/repositories/{name}/tags/{tag}") as r:
            stamp = json.load(r).get("tag_last_pushed") or ""
        return datetime.datetime.fromisoformat(stamp.replace("Z", "+00:00"))
    except Exception:
        return None


def text(root, tag):
    el = root.find(tag)
    return (el.text or "").strip() if el is not None else ""


def check_template(path):
    rel = path.relative_to(ROOT).as_posix()
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError as e:
        error(rel, f"XML is not well-formed: {e}")
        return
    if root.tag != "Container":
        error(rel, f"root element is <{root.tag}>, expected <Container>")
        return

    for tag in REQUIRED:
        if not text(root, tag):
            error(rel, f"<{tag}> is missing or empty")

    template_url = text(root, "TemplateURL")
    if template_url and template_url != f"{RAW}/{rel}":
        error(rel, f"<TemplateURL> is {template_url}, expected {RAW}/{rel}")

    date = text(root, "Date")
    if not date:
        warn(rel, "<Date> is missing; set it (YYYY-MM-DD) and add a line to <Changes> on every change")
    elif date > datetime.date.today().isoformat():
        warn(rel, f"<Date> {date} is in the future")

    for cfg in root.findall("Config"):
        name, ctype = cfg.get("Name", ""), cfg.get("Type", "")
        if name != name.strip():
            warn(rel, f'Config "{name}" has leading/trailing spaces in its name')
        if ctype == "Port" and not cfg.get("Target", "").strip():
            error(rel, f'port "{name.strip()}" has no container port (Target)')

    image = text(root, "Repository")
    image_state = "-"
    if image:
        registry, repo, tag = split_image(image)
        status = manifest_status(registry, repo, tag)
        if status == 200:
            image_state = "ok"
        elif status in (401, 403, 404):
            image_state = f"missing ({status})"
            error(rel, f"image {image} not found or not public (registry answered {status})")
        else:
            image_state = f"unknown ({status})"
            warn(rel, f"could not check image {image}: {status}")
        if registry == "registry-1.docker.io" and status == 200:
            pushed = dockerhub_last_push(repo, tag)
            if pushed:
                age = (datetime.datetime.now(datetime.timezone.utc) - pushed).days
                image_state += f", pushed {pushed.date()}"
                if age > STALE_DAYS:
                    warn(rel, f"{image} was last pushed {age} days ago; check whether upstream is still maintained")

    icon = text(root, "Icon")
    if icon:
        status, ctype = url_status(icon)
        if status != 200:
            error(rel, f"icon {icon} answered {status}")
        elif not ctype.startswith("image/"):
            error(rel, f"icon {icon} is {ctype or 'not an image'}")

    for tag in ("Support", "Project"):
        url = text(root, tag)
        if url.startswith("http"):
            status, _ = url_status(url)
            if status != 200:
                warn(rel, f"<{tag}> {url} answered {status}")

    rows.append((rel, image or "-", image_state, date or "-"))


def main():
    templates = sorted(p for p in ROOT.glob("*/*.xml"))
    for path in templates:
        check_template(path)
    try:
        ET.parse(ROOT / "ca_profile.xml")
    except (ET.ParseError, FileNotFoundError) as e:
        error("ca_profile.xml", f"not readable: {e}")

    gha = os.environ.get("GITHUB_ACTIONS") == "true"
    for kind, items in (("error", errors), ("warning", warnings)):
        for file, msg in items:
            print(f"::{kind} file={file}::{msg}" if gha else f"{kind.upper()} {file}: {msg}")

    summary = ["| Template | Image | Image check | Date |", "|---|---|---|---|"]
    summary += [f"| {r[0]} | `{r[1]}` | {r[2]} | {r[3]} |" for r in rows]
    summary += ["", f"{len(templates)} templates, {len(errors)} errors, {len(warnings)} warnings"]
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as f:
            f.write("\n".join(summary) + "\n")
    print("\n".join(summary))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
