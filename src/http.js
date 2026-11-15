// Response + identity plumbing shared by every route module.

export const json = (data, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { 'content-type': 'application/json' } });

export const fail = (msg, status = 400) => json({ error: msg }, status);

// Minutes east of UTC from a client ("-480" for US Pacific standard time), or null if it is not a plausible
// offset. Sent as the x-tz-offset header by the web app and as a tz_offset form field by the device apps.
export const tzOffset = (v) => {
  const n = v == null || (typeof v === 'string' && v.trim() === '') ? NaN : Number(v);
  return Number.isInteger(n) && n >= -840 && n <= 840 ? n : null;
};

export const uid = () => crypto.randomUUID();

// Single-user deploys: Cloudflare Access puts the email on the request, local dev
// has no header at all. Everything is scoped by this string.
export const ownerOf = (req) => req.headers.get('cf-access-authenticated-user-email') || 'local';
