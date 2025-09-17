import { fetchAuthSession } from 'aws-amplify/auth';

const API_BASE = import.meta.env.VITE_API_BASE_URL as string;

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

async function idToken(): Promise<string> {
  const { tokens } = await fetchAuthSession();
  const tok = tokens?.idToken?.toString();
  if (!tok) throw new Error('No ID token');
  return tok;
}

export async function listClaims(): Promise<ListResp> {
  const token = await idToken();
  const r = await fetch(`${API_BASE}/claims`, { headers: { Authorization: `Bearer ${token}` } });
  if (!r.ok) throw new Error(`List failed: ${r.status}`);
  return r.json();
}

type PresignReq = { filename: string; tags: string[]; client: string; content_type?: string };
type PresignResp = {
  claim_id: string; s3_key: string; presigned_url: string; expires_in: number;
  content_type: string; upload_headers: Record<string,string>;
};

export async function presignUpload(body: PresignReq): Promise<PresignResp> {
  const token = await idToken();
  const r = await fetch(`${API_BASE}/claims/presign`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ ...body, content_type: body.content_type ?? 'text/plain' })
  });
  if (!r.ok) throw new Error(`Presign failed: ${r.status}`);
  return r.json();
}

export async function putToS3(url: string, headers: Record<string,string>, file: File) {
  const r = await fetch(url, { method: 'PUT', headers, body: file });
  if (!r.ok) throw new Error(`S3 PUT failed: ${r.status}`);
}
