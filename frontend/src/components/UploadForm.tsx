import React, { useState } from 'react';
import { presignUpload, putToS3 } from '../api';
import { Upload, RefreshCw, FileText, Tag, Building2, CheckCircle2, AlertCircle } from 'lucide-react';

export default function UploadForm({ onUploaded }: { onUploaded: () => void }) {
  const [file, setFile] = useState<File | null>(null);
  const [tags, setTags] = useState('');
  const [client, setClient] = useState('');
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');
  const [dragActive, setDragActive] = useState(false);

  const handleDrag = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === "dragenter" || e.type === "dragover") {
      setDragActive(true);
    } else if (e.type === "dragleave") {
      setDragActive(false);
    }
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      setFile(e.dataTransfer.files[0]);
    }
  };

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
        filename: file.name,
        client: client.trim(),
        tags: tagList,
        content_type: 'text/plain'
      });
      await putToS3(p.presigned_url, p.upload_headers, file);
      setMsg('Upload complete!');
      setFile(null);
      setTags('');
      setClient('');
      onUploaded();
    } catch (err: any) {
      setMsg(err?.message ?? 'Upload failed');
    } finally {
      setBusy(false);
    }
  };

  return (
    <form onSubmit={submit} style={{
      background: 'rgba(255, 255, 255, 0.05)',
      backdropFilter: 'blur(10px)',
      borderRadius: '20px',
      border: '1px solid rgba(255, 255, 255, 0.1)',
      padding: '2rem',
      display: 'flex',
      flexDirection: 'column',
      gap: '1.5rem',
      height: 'fit-content',
      transition: 'all 0.3s ease'
    }}>
      <h2 style={{
        fontSize: '1.5rem',
        fontWeight: '700',
        color: 'rgba(255, 255, 255, 0.95)',
        display: 'flex',
        alignItems: 'center',
        gap: '10px',
        margin: 0
      }}>
        <Upload style={{ color: '#667eea' }} />
        Upload Claim Document
      </h2>
      
      {/* Drag and Drop Zone */}
      <div 
        onDragEnter={handleDrag}
        onDragLeave={handleDrag}
        onDragOver={handleDrag}
        onDrop={handleDrop}
        style={{
          border: `2px dashed ${
            dragActive ? '#667eea' : 
            file ? 'rgba(34, 197, 94, 0.5)' : 
            'rgba(255, 255, 255, 0.2)'
          }`,
          borderRadius: '16px',
          padding: '3rem 2rem',
          textAlign: 'center',
          transition: 'all 0.3s ease',
          position: 'relative',
          background: dragActive ? 
            'rgba(102, 126, 234, 0.1)' : 
            file ? 'rgba(34, 197, 94, 0.05)' : 
            'rgba(255, 255, 255, 0.02)',
          cursor: 'pointer'
        }}
      >
        <input 
          type="file" 
          accept=".txt,text/plain" 
          onChange={(e) => setFile(e.target.files?.[0] ?? null)}
          style={{
            position: 'absolute',
            opacity: 0,
            width: '100%',
            height: '100%',
            cursor: 'pointer',
            top: 0,
            left: 0
          }}
          id="file-upload"
        />
        <label htmlFor="file-upload" style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: '12px',
          cursor: 'pointer'
        }}>
          {file ? (
            <>
              <FileText size={32} style={{ color: '#22c55e' }} />
              <span style={{ 
                fontWeight: '600', 
                color: 'rgba(255, 255, 255, 0.95)' 
              }}>
                {file.name}
              </span>
              <span style={{ 
                fontSize: '0.875rem', 
                color: 'rgba(255, 255, 255, 0.6)' 
              }}>
                {(file.size / 1024).toFixed(2)} KB
              </span>
            </>
          ) : (
            <>
              <Upload size={32} style={{ color: '#667eea' }} />
              <span style={{ 
                fontWeight: '500', 
                color: 'rgba(255, 255, 255, 0.9)' 
              }}>
                Drop your .txt file here or click to browse
              </span>
              <span style={{ 
                fontSize: '0.875rem', 
                color: 'rgba(255, 255, 255, 0.5)' 
              }}>
                Only text files are accepted
              </span>
            </>
          )}
        </label>
      </div>

      {/* Client Input */}
      <div style={{ position: 'relative' }}>
        <Building2 style={{
          position: 'absolute',
          left: '16px',
          top: '50%',
          transform: 'translateY(-50%)',
          color: 'rgba(255, 255, 255, 0.4)',
          pointerEvents: 'none'
        }} size={20} />
        <input 
          placeholder="Client name (e.g., Acme Insurance)" 
          value={client} 
          onChange={e => setClient(e.target.value)}
          style={{
            width: '100%',
            padding: '14px 16px 14px 48px',
            background: 'rgba(255, 255, 255, 0.05)',
            border: '1px solid rgba(255, 255, 255, 0.1)',
            borderRadius: '12px',
            color: 'rgba(255, 255, 255, 0.9)',
            fontSize: '0.95rem',
            transition: 'all 0.3s ease',
            outline: 'none'
          }}
          onFocus={(e) => {
            e.currentTarget.style.borderColor = 'rgba(102, 126, 234, 0.5)';
            e.currentTarget.style.background = 'rgba(255, 255, 255, 0.08)';
          }}
          onBlur={(e) => {
            e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.1)';
            e.currentTarget.style.background = 'rgba(255, 255, 255, 0.05)';
          }}
        />
      </div>

      {/* Tags Input */}
      <div>
        <div style={{ position: 'relative' }}>
          <Tag style={{
            position: 'absolute',
            left: '16px',
            top: '50%',
            transform: 'translateY(-50%)',
            color: 'rgba(255, 255, 255, 0.4)',
            pointerEvents: 'none'
          }} size={20} />
          <input 
            placeholder='Tags (comma-separated, e.g., "urgent, auto")' 
            value={tags} 
            onChange={e => setTags(e.target.value)}
            style={{
              width: '100%',
              padding: '14px 16px 14px 48px',
              background: 'rgba(255, 255, 255, 0.05)',
              border: '1px solid rgba(255, 255, 255, 0.1)',
              borderRadius: '12px',
              color: 'rgba(255, 255, 255, 0.9)',
              fontSize: '0.95rem',
              transition: 'all 0.3s ease',
              outline: 'none'
            }}
            onFocus={(e) => {
              e.currentTarget.style.borderColor = 'rgba(102, 126, 234, 0.5)';
              e.currentTarget.style.background = 'rgba(255, 255, 255, 0.08)';
            }}
            onBlur={(e) => {
              e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.1)';
              e.currentTarget.style.background = 'rgba(255, 255, 255, 0.05)';
            }}
          />
        </div>
        
        {/* Tag Preview */}
        {tags && (
          <div style={{ 
            display: 'flex', 
            flexWrap: 'wrap', 
            gap: '6px', 
            marginTop: '8px' 
          }}>
            {tags.split(',').map((tag) => tag.trim()).filter(Boolean).map((tag, i) => (
              <span key={i} style={{
                padding: '4px 10px',
                background: 'rgba(102, 126, 234, 0.2)',
                color: '#a5b4fc',
                borderRadius: '6px',
                fontSize: '0.85rem',
                border: '1px solid rgba(102, 126, 234, 0.3)',
                animation: 'fadeIn 0.3s ease-out'
              }}>
                {tag}
              </span>
            ))}
          </div>
        )}
      </div>

      {/* Submit Button */}
      <button type="submit" disabled={busy} style={{
        padding: '14px 24px',
        background: busy ? 
          'rgba(102, 126, 234, 0.5)' : 
          'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
        color: 'white',
        border: 'none',
        borderRadius: '12px',
        fontWeight: '600',
        fontSize: '1rem',
        cursor: busy ? 'not-allowed' : 'pointer',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: '8px',
        transition: 'all 0.3s ease',
        transform: busy ? 'none' : 'translateY(0)',
        boxShadow: busy ? 'none' : '0 4px 15px rgba(102, 126, 234, 0.2)'
      }}
      onMouseEnter={(e) => {
        if (!busy) {
          e.currentTarget.style.transform = 'translateY(-2px)';
          e.currentTarget.style.boxShadow = '0 10px 25px rgba(102, 126, 234, 0.3)';
        }
      }}
      onMouseLeave={(e) => {
        if (!busy) {
          e.currentTarget.style.transform = 'translateY(0)';
          e.currentTarget.style.boxShadow = '0 4px 15px rgba(102, 126, 234, 0.2)';
        }
      }}>
        {busy ? (
          <>
            <RefreshCw size={20} style={{ 
              animation: 'spin 1s linear infinite' 
            }} />
            Uploading...
          </>
        ) : (
          <>
            <Upload size={20} />
            Upload Claim
          </>
        )}
      </button>
      
      {/* Status Message */}
      {msg && (
        <div style={{
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          padding: '12px 16px',
          borderRadius: '10px',
          fontSize: '0.9rem',
          background: msg.includes('complete') ? 
            'rgba(34, 197, 94, 0.1)' : 
            'rgba(239, 68, 68, 0.1)',
          color: msg.includes('complete') ? '#22c55e' : '#ef4444',
          border: `1px solid ${
            msg.includes('complete') ? 
            'rgba(34, 197, 94, 0.2)' : 
            'rgba(239, 68, 68, 0.2)'
          }`,
          animation: 'slideIn 0.3s ease-out'
        }}>
          {msg.includes('complete') ? 
            <CheckCircle2 size={18} /> : 
            <AlertCircle size={18} />
          }
          {msg}
        </div>
      )}

      <style>{`
        @keyframes spin {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
        
        @keyframes fadeIn {
          from { opacity: 0; transform: scale(0.95); }
          to { opacity: 1; transform: scale(1); }
        }
        
        @keyframes slideIn {
          from { opacity: 0; transform: translateX(-10px); }
          to { opacity: 1; transform: translateX(0); }
        }
      `}</style>
    </form>
  );
}