/**
 * IPTV Stream Proxy — Cloudflare Worker
 *
 * Bypasses two browser limitations the IPTV web app hits when hosted on
 * HTTPS GitHub Pages:
 *   1. Mixed-content blocking (HTTPS pages can't fetch http:// resources).
 *   2. CORS rejections (many stream servers don't send the right headers).
 *
 * Endpoint:
 *   GET https://<your-worker>.workers.dev/?url=<percent-encoded-stream-url>
 *
 * The worker fetches the target server-side (where mixed-content and CORS
 * don't apply), forwards Range headers for video seeking, and streams the
 * body back with permissive CORS headers added.
 *
 * Free-tier note: 100k requests/day. Each HLS segment is one request.
 * The web app only routes http:// streams through here by default, so
 * direct HTTPS streams don't burn quota.
 */

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
  'Access-Control-Allow-Headers': '*',
  'Access-Control-Expose-Headers': '*',
  'Access-Control-Max-Age': '86400'
};

// Some IPTV servers reject requests without a "real" User-Agent.
const FAKE_UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

export default {
  async fetch(request) {
    // CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const url = new URL(request.url);
    const target = url.searchParams.get('url');
    if (!target) return errorResp('Missing ?url= parameter', 400);

    let targetUrl;
    try { targetUrl = new URL(target); }
    catch { return errorResp('Invalid target URL', 400); }

    if (!/^https?:$/.test(targetUrl.protocol)) {
      return errorResp('Only http/https URLs are proxied', 400);
    }

    // Forward Range so video seeking works.
    const upstreamHeaders = { 'User-Agent': FAKE_UA };
    const range = request.headers.get('Range');
    if (range) upstreamHeaders['Range'] = range;

    let upstream;
    try {
      upstream = await fetch(targetUrl.href, {
        method: request.method === 'HEAD' ? 'HEAD' : 'GET',
        headers: upstreamHeaders,
        redirect: 'follow'
      });
    } catch (err) {
      return errorResp('Upstream fetch failed: ' + err.message, 502);
    }

    // Pipe response back with CORS headers layered on.
    const respHeaders = new Headers(upstream.headers);
    for (const [k, v] of Object.entries(CORS_HEADERS)) respHeaders.set(k, v);

    return new Response(upstream.body, {
      status: upstream.status,
      statusText: upstream.statusText,
      headers: respHeaders
    });
  }
};

function errorResp(message, status) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS }
  });
}
