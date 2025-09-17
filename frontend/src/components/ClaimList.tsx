import React from 'react';
import type { Claim } from '../api';

export default function ClaimList({ claims, refresh, loading }:{
  claims: Claim[]; refresh: () => void; loading: boolean;
}) {
  return (
    <div style={{ display:'grid', gap:12 }}>
      <div style={{ display:'flex', justifyContent:'space-between' }}>
        <h2>Your Uploads</h2>
        <button onClick={refresh} disabled={loading}>{loading ? 'Refreshing…' : 'Refresh'}</button>
      </div>
      {claims.length === 0 ? (
        <div>No uploads yet.</div>
      ) : (
        <table style={{ borderCollapse:'collapse', width:'100%' }}>
          <thead>
            <tr>
              <th style={{ textAlign:'left', borderBottom:'1px solid #ddd' }}>File</th>
              <th style={{ textAlign:'left', borderBottom:'1px solid #ddd' }}>Client</th>
              <th style={{ textAlign:'left', borderBottom:'1px solid #ddd' }}>Tags</th>
              <th style={{ textAlign:'left', borderBottom:'1px solid #ddd' }}>Uploaded</th>
              <th style={{ textAlign:'left', borderBottom:'1px solid #ddd' }}>Status</th>
            </tr>
          </thead>
          <tbody>
            {claims.map(c=>(
              <tr key={c.ClaimID}>
                <td style={{ padding:'6px 4px' }}>{c.Filename}</td>
                <td style={{ padding:'6px 4px' }}>{c.Client}</td>
                <td style={{ padding:'6px 4px' }}>{c.Tags.join(', ')}</td>
                <td style={{ padding:'6px 4px' }}>{new Date(c.UploadedAt).toLocaleString()}</td>
                <td style={{ padding:'6px 4px' }}>{c.Status}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
