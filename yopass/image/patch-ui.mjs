// Changes to the Yopass web UI before the build. Run in website/.
//
// 1. Any URL path: the UI also runs under a path behind a reverse proxy
//    (https://example.com/yopass/), not only at the root of a domain.
//    Upstream uses absolute paths for the logo, the home link and "create
//    another", and builds secret links from window.location.origin. Here
//    they become relative, and links keep the page's path. The API base and
//    the asset URLs are made relative by the build (YOPASS_BACKEND_URL=. and
//    --base=./, see the Dockerfile).
// 2. HTTPS notice: browsers only offer WebCrypto on HTTPS or localhost.
//    Without it the UI stays blank, for example on http://<server-ip>:1337.
//    https-check.js says what is missing instead.
//
// Fails if a spot is missing, so an upstream change breaks the image build
// instead of shipping a UI that only works at the root.
import { readFileSync, writeFileSync } from 'node:fs';

const pageBase =
  "(window.location.origin + window.location.pathname).replace(/\\/+$/, '')";

const patches = {
  'index.html': [
    ['src="/theme-init.js"', 'src="./theme-init.js"'],
    ['<div id="root"></div>', '<div id="root"></div>\n    <script src="./https-check.js"></script>'],
  ],
  'src/shared/components/Navbar.tsx': [
    ['href="/"', 'href="./"'],
    ["'/yopass.svg'", "'./yopass.svg'"],
    ["'/yopass-full-dark.svg'", "'./yopass-full-dark.svg'"],
    ["'/yopass-full.svg'", "'./yopass-full.svg'"],
  ],
  'src/features/display-secret/Result.tsx': [
    [': window.location.origin;', `: ${pageBase};`],
    ["window.location.href = '/';", "window.location.href = './';"],
  ],
  'src/features/request-secret/requestLink.ts': [
    [': window.location.origin;', `: ${pageBase};`],
  ],
};

for (const [file, replacements] of Object.entries(patches)) {
  let text = readFileSync(file, 'utf8');
  for (const [from, to] of replacements) {
    if (!text.includes(from)) {
      console.error(`patch-ui.mjs: "${from}" not found in ${file}`);
      process.exit(1);
    }
    text = text.replaceAll(from, to);
  }
  writeFileSync(file, text);
  console.log(`patch-ui.mjs: patched ${file}`);
}

writeFileSync(
  'public/https-check.js',
  `// Added by the Unraid image (hoody424/unraid-templates): Yopass encrypts in
// the browser, and browsers only allow that on HTTPS pages or on localhost.
if (!window.isSecureContext) {
  document.addEventListener('DOMContentLoaded', function () {
    document.body.innerHTML =
      '<div style="max-width:40rem;margin:4rem auto;padding:0 1rem;' +
      'font-family:system-ui,sans-serif;line-height:1.5">' +
      '<h1 style="font-size:1.5rem;font-weight:700;margin-bottom:.5rem">' +
      'Yopass needs HTTPS</h1>' +
      '<p>Secrets are encrypted in your browser, and browsers only allow ' +
      'that on HTTPS pages (or on localhost). Open Yopass through your ' +
      'reverse proxy with an https:// address.</p></div>';
  });
}
`,
);
console.log('patch-ui.mjs: wrote public/https-check.js');
