import React, { useState } from 'react';
import { presignUpload, putToS3 } from '../api';

export default function UploadForm({ onUploaded }: { onUploaded: () => void }) {
  const [file, setFile] = useState<File | null>(null);
  const [tags, setTags] = useState('');
  const [client, setClient] = useState('');
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setMsg('');
    if (!file) return setMsg('Choose a .txt file');
    if (!file.name.toLowerCase().endsWith('.txt')) return setMsg('Only .txt files allowed');
    if (!client.trim()) return setMsg('Client required');

    try {
      setBusy(true);
      const tagList = tags.split(',').map(t => t.trim()).filter(Boolean);
      const p = await presignUpload({
        filename: file.name, client: client.trim(), tags: tagList, content_type: 'text/plain'
      });
      await putToS3(p.presigned_url, p.upload_headers, file);
      setMsg('Upload complete (refresh may take a moment)…');
      setFile(null); setTags(''); setClient('');
      onUploaded();
    } catch (err: any) {
      setMsg(err?.message ?? 'Upload failed');
    } finally {
      setBusy(false);
    }
  };

  return (
    <form onSubmit={submit} style={{ display: 'grid', gap: 12, maxWidth: 480 }}>
      <h2>Upload Claim (.txt)</h2>
      <input type="file" accept=".txt,text/plain" onChange={(e)=>setFile(e.target.files?.[0] ?? null)}/>
      <input placeholder="Client (e.g., Acme Insurance)" value={client} onChange={e=>setClient(e.target.value)}/>
      <input placeholder='Tags (e.g., "car accident, urgent")' value={tags} onChange={e=>setTags(e.target.value)}/>
      <button disabled={busy}>{busy ? 'Uploading…' : 'Upload'}</button>
      {msg && <div>{msg}</div>}
    </form>
  );
}
