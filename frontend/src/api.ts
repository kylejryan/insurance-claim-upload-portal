// frontend/src/api.ts
import { fetchAuthSession } from 'aws-amplify/auth';

const RAW_API_BASE = (import.meta.env.VITE_API_BASE_URL as string | undefined) ?? '';

function getApiBase(): string {
  const base = RAW_API_BASE.trim();
  if (!base) throw new Error('Frontend not configured: missing VITE_API_BASE_URL.');
  try {
    const u = new URL(base);
    // normalize: no trailing slash
    return u.toString().replace(/\/$/, '');
  } catch {
    throw new Error(`Frontend misconfigured: invalid VITE_API_BASE_URL "${base}".`);
  }
}

async function idToken(): Promise<string> {
  const { tokens } = await fetchAuthSession();
  const tok = tokens?.idToken?.toString();
  if (!tok) throw new Error('Not authenticated (no ID token).');
  return tok;
}

async function fetchJson(input: RequestInfo, init?: RequestInit) {
  const resp = await fetch(input, init);
  const text = await resp.text();
  if (!resp.ok) {
    // surface backend message if any
    let msg = `HTTP ${resp.status}`;
    try {
      const j = JSON.parse(text);
      if (j?.message) msg = j.message;
      else if (j?.error) msg = j.error;
    } catch { /* plain text or html */ }
    throw new Error(`Request failed: ${msg}`);
  }
  // handle non-JSON (e.g., HTML from wrong URL)
  try { return JSON.parse(text); } catch {
    throw new Error('Unexpected non-JSON response from API (check API base URL).');
  }
}

/** ===== Types ===== */
export type Claim = {
  ClaimID: string;
  UserID: string;
  Filename: string;
  S3Key: string;
  Tags: string[];
  Client: string;
  Status: 'UPLOADING' | 'COMPLETE';
  UploadedAt: string;
  SizeBytes: number;
  ETag: string;
};
export type ListResp = { user_id: string; items: Claim[] };

type PresignReq = { filename: string; tags: string[]; client: string; content_type?: string };
export type PresignResp = {
  claim_id: string;
  s3_key: string;
  presigned_url: string;
  expires_in: number;
  content_type: string;
  upload_headers: Record<string, string>;
};

/** ===== API calls ===== */
export async function listClaims(): Promise<ListResp> {
  const base = getApiBase();
  const token = await idToken();
  return fetchJson(`${base}/claims`, {
    headers: { Authorization: `Bearer ${token}` },
  });
}

export async function presignUpload(body: PresignReq): Promise<PresignResp> {
  const base = getApiBase();
  const token = await idToken();
  return fetchJson(`${base}/claims/presign`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ ...body, content_type: body.content_type ?? 'text/plain' }),
  });
}

export async function putToS3(url: string, headers: Record<string, string>, file: File) {
  const r = await fetch(url, { method: 'PUT', headers, body: file });
  if (!r.ok) throw new Error(`S3 PUT failed: ${r.status}`);
}
