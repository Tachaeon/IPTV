# IPTV Stream Proxy — Cloudflare Worker

A tiny serverless proxy that bypasses the two biggest browser limitations
for IPTV streams: HTTPS→HTTP mixed-content blocking and CORS rejections.

The web app routes any `http://` stream URL through this Worker
automatically once it's configured. HTTPS streams continue to go direct
so they don't eat into the quota.

## What it does

1. Accepts `GET https://your-worker.workers.dev/?url=<encoded-url>`
2. Fetches that URL server-side with a desktop Chrome `User-Agent`
3. Streams the response back with `Access-Control-Allow-Origin: *`
4. Forwards `Range` headers so video seeking works

## Free-tier limits

Cloudflare's free Workers plan allows **100,000 requests per day**.
Each HLS segment fetch is one request — roughly 12 segments/minute per
active stream — so plan on ~5–6 hours of daily streaming *through* the
proxy before hitting the limit. The web app only proxies `http://`
streams, so HTTPS playback is free.

## Deploying (first-time Cloudflare user)

1. **Sign up** at <https://dash.cloudflare.com/sign-up> (free, no card).
2. From the dashboard left sidebar, click **Workers & Pages**.
3. Click **Create application** → **Create Worker**.
4. Name it (e.g. `iptv-proxy`). This becomes the subdomain
   of your worker URL. Click **Deploy** to publish the stub.
5. On the worker page, click **Edit code** (top right).
6. **Replace** the entire `worker.js` contents in the editor with the
   contents of `worker.js` from this folder.
7. Click **Save and deploy** (top right).
8. Copy the URL shown above the editor — it will look like:
   `https://iptv-proxy.your-subdomain.workers.dev`

## Wiring the web app

Open `index.html` and find the `PROXY_URL` constant near the top of the
script. Set it to your worker URL (no trailing slash, no `/?url=` suffix):

```js
const PROXY_URL = 'https://iptv-proxy.your-subdomain.workers.dev';
```

Commit and push. The GitHub Pages build picks it up; refresh the live
site and `http://` streams should now play.

Leaving `PROXY_URL` empty disables production proxying entirely (the app
will just attempt direct fetches and fail on mixed-content streams).

## Verifying it works

1. Open the live site after pushing.
2. F12 → **Network** tab.
3. Click any stream whose URL is `http://…` (you can spot these in the
   `pluto` or `samsung` country playlists). The request in the Network
   tab should go to your worker URL, not the original `http://` host.
4. The stream should play. Before this change, it would have errored
   with a mixed-content warning in the console.

## Updating the worker code

Edit `worker.js` locally and either:
- Paste the new contents into the CF dashboard editor and click
  **Save and deploy**, or
- Use the `wrangler` CLI: `npm i -g wrangler && wrangler login && wrangler deploy worker.js`

## Caveats

The worker fixes **mixed content + CORS + User-Agent**. It does *not*
fix:
- Codec issues (browser can't decode H.265, AC3 audio, etc.)
- DRM-protected streams
- Non-HLS protocols (RTMP/RTSP)
- Geo-blocking based on the worker's IP (Cloudflare's edge IP)

Those are unfixable in a browser without leaving GitHub Pages and the
worker pattern.
