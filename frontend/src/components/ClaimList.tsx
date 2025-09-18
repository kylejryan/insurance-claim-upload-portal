import { useState } from 'react';
import type { Claim } from '../api';
import { RefreshCw, FileText, Building2, Clock, CheckCircle2, Tag, Search, Activity } from 'lucide-react';

export default function ClaimList({ claims, refresh, loading }: {
  claims: Claim[]; 
  refresh: () => void; 
  loading: boolean;
}) {
  const [searchTerm, setSearchTerm] = useState('');
  const [filterStatus, setFilterStatus] = useState<string>('all');
  
  // Filter claims based on search and status
  const filteredClaims = claims.filter(claim => {
    const matchesSearch = 
      claim.Filename.toLowerCase().includes(searchTerm.toLowerCase()) ||
      claim.Client.toLowerCase().includes(searchTerm.toLowerCase()) ||
      claim.Tags.some(tag => tag.toLowerCase().includes(searchTerm.toLowerCase()));
    const matchesStatus = filterStatus === 'all' || claim.Status === filterStatus;
    return matchesSearch && matchesStatus;
  });

  return (
    <div style={{
      background: 'rgba(255, 255, 255, 0.05)',
      backdropFilter: 'blur(10px)',
      borderRadius: '20px',
      border: '1px solid rgba(255, 255, 255, 0.1)',
      padding: '2rem',
      display: 'flex',
      flexDirection: 'column',
      gap: '1.5rem',
      transition: 'all 0.3s ease'
    }}>
      {/* Header Section */}
      <div style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        flexWrap: 'wrap',
        gap: '1rem'
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
          <Activity style={{ color: '#667eea' }} />
          Recent Claims
        </h2>
        
        {/* Controls */}
        <div style={{ 
          display: 'flex', 
          gap: '12px', 
          alignItems: 'center',
          flexWrap: 'wrap'
        }}>
          {/* Search Input */}
          <div style={{ position: 'relative' }}>
            <Search style={{
              position: 'absolute',
              left: '12px',
              top: '50%',
              transform: 'translateY(-50%)',
              color: 'rgba(255, 255, 255, 0.4)',
              pointerEvents: 'none'
            }} size={18} />
            <input 
              type="text"
              placeholder="Search claims..."
              value={searchTerm}
              onChange={e => setSearchTerm(e.target.value)}
              style={{
                padding: '10px 12px 10px 38px',
                background: 'rgba(255, 255, 255, 0.05)',
                border: '1px solid rgba(255, 255, 255, 0.1)',
                borderRadius: '10px',
                color: 'rgba(255, 255, 255, 0.9)',
                fontSize: '0.9rem',
                width: '200px',
                transition: 'all 0.3s ease',
                outline: 'none'
              }}
              onFocus={(e) => {
                e.currentTarget.style.borderColor = 'rgba(102, 126, 234, 0.5)';
                e.currentTarget.style.background = 'rgba(255, 255, 255, 0.08)';
                e.currentTarget.style.width = '250px';
              }}
              onBlur={(e) => {
                e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.1)';
                e.currentTarget.style.background = 'rgba(255, 255, 255, 0.05)';
                e.currentTarget.style.width = '200px';
              }}
            />
          </div>
          
          {/* Status Filter */}
          <select 
            value={filterStatus}
            onChange={e => setFilterStatus(e.target.value)}
            style={{
              padding: '10px 14px',
              background: 'rgba(255, 255, 255, 0.05)',
              border: '1px solid rgba(255, 255, 255, 0.1)',
              borderRadius: '10px',
              color: 'rgba(255, 255, 255, 0.9)',
              fontSize: '0.9rem',
              cursor: 'pointer',
              transition: 'all 0.3s ease',
              outline: 'none'
            }}
            onFocus={(e) => {
              e.currentTarget.style.borderColor = 'rgba(102, 126, 234, 0.5)';
            }}
            onBlur={(e) => {
              e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.1)';
            }}
          >
            <option value="all" style={{ background: '#1a1a2e' }}>All Status</option>
            <option value="COMPLETE" style={{ background: '#1a1a2e' }}>Complete</option>
            <option value="UPLOADING" style={{ background: '#1a1a2e' }}>Uploading</option>
          </select>
          
          {/* Refresh Button */}
          <button 
            onClick={refresh} 
            disabled={loading} 
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              padding: '10px 16px',
              background: 'rgba(102, 126, 234, 0.1)',
              color: '#a5b4fc',
              border: '1px solid rgba(102, 126, 234, 0.2)',
              borderRadius: '10px',
              fontSize: '0.9rem',
              cursor: loading ? 'not-allowed' : 'pointer',
              fontWeight: '500',
              opacity: loading ? 0.6 : 1,
              transition: 'all 0.3s ease'
            }}
            onMouseEnter={(e) => {
              if (!loading) {
                e.currentTarget.style.background = 'rgba(102, 126, 234, 0.2)';
                e.currentTarget.style.transform = 'translateY(-1px)';
              }
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'rgba(102, 126, 234, 0.1)';
              e.currentTarget.style.transform = 'translateY(0)';
            }}
          >
            <RefreshCw size={18} style={loading ? { 
              animation: 'spin 1s linear infinite' 
            } : {}} />
            {loading ? 'Refreshing' : 'Refresh'}
          </button>
        </div>
      </div>

      {/* Claims Display */}
      {filteredClaims.length === 0 ? (
        <div style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          padding: '4rem 2rem',
          color: 'rgba(255, 255, 255, 0.5)',
          gap: '12px',
          textAlign: 'center'
        }}>
          <FileText size={48} style={{ 
            color: 'rgba(255, 255, 255, 0.2)' 
          }} />
          <p style={{ 
            fontSize: '1.1rem', 
            margin: 0 
          }}>
            No claims found
          </p>
          <span style={{ 
            fontSize: '0.875rem', 
            color: 'rgba(255, 255, 255, 0.4)' 
          }}>
            {searchTerm || filterStatus !== 'all' 
              ? 'Try adjusting your filters' 
              : 'Upload your first claim to get started'}
          </span>
        </div>
      ) : (
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))',
          gap: '1.5rem'
        }}>
          {filteredClaims.map((claim, index) => (
            <div 
              key={claim.ClaimID} 
              style={{
                background: 'rgba(255, 255, 255, 0.03)',
                border: '1px solid rgba(255, 255, 255, 0.1)',
                borderRadius: '16px',
                padding: '1.5rem',
                transition: 'all 0.3s ease',
                cursor: 'pointer',
                animation: `fadeInUp 0.4s ease-out ${index * 0.05}s both`,
                position: 'relative',
                overflow: 'hidden'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.background = 'rgba(255, 255, 255, 0.06)';
                e.currentTarget.style.borderColor = 'rgba(102, 126, 234, 0.3)';
                e.currentTarget.style.transform = 'translateY(-3px)';
                e.currentTarget.style.boxShadow = '0 10px 30px rgba(0, 0, 0, 0.2)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.background = 'rgba(255, 255, 255, 0.03)';
                e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.1)';
                e.currentTarget.style.transform = 'translateY(0)';
                e.currentTarget.style.boxShadow = 'none';
              }}
            >
              {/* Claim Header */}
              <div style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'flex-start',
                marginBottom: '1rem'
              }}>
                <div style={{ 
                  display: 'flex', 
                  alignItems: 'center', 
                  gap: '8px',
                  flex: 1,
                  minWidth: 0
                }}>
                  <FileText size={20} style={{ 
                    color: '#667eea',
                    flexShrink: 0
                  }} />
                  <span style={{ 
                    fontWeight: '600', 
                    color: 'rgba(255, 255, 255, 0.95)',
                    fontSize: '1rem',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                    whiteSpace: 'nowrap'
                  }}>
                    {claim.Filename}
                  </span>
                </div>
                
                {/* Status Badge */}
                <span style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px',
                  padding: '4px 8px',
                  borderRadius: '6px',
                  fontSize: '0.75rem',
                  fontWeight: '500',
                  flexShrink: 0,
                  background: claim.Status === 'COMPLETE' ? 
                    'rgba(34, 197, 94, 0.1)' : 
                    'rgba(251, 191, 36, 0.1)',
                  color: claim.Status === 'COMPLETE' ? 
                    '#22c55e' : 
                    '#fbbf24',
                  border: `1px solid ${
                    claim.Status === 'COMPLETE' ? 
                    'rgba(34, 197, 94, 0.2)' : 
                    'rgba(251, 191, 36, 0.2)'
                  }`
                }}>
                  {claim.Status === 'COMPLETE' ? 
                    <CheckCircle2 size={14} /> : 
                    <Clock size={14} />
                  }
                  {claim.Status}
                </span>
              </div>
              
              {/* Claim Details */}
              <div style={{ 
                display: 'flex', 
                flexDirection: 'column', 
                gap: '10px' 
              }}>
                {/* Client */}
                <div style={{ 
                  display: 'flex', 
                  alignItems: 'center', 
                  gap: '8px' 
                }}>
                  <Building2 size={16} style={{ 
                    color: 'rgba(255, 255, 255, 0.5)',
                    flexShrink: 0
                  }} />
                  <span style={{ 
                    color: 'rgba(255, 255, 255, 0.8)', 
                    fontSize: '0.9rem',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                    whiteSpace: 'nowrap'
                  }}>
                    {claim.Client}
                  </span>
                </div>
                
                {/* Upload Time */}
                <div style={{ 
                  display: 'flex', 
                  alignItems: 'center', 
                  gap: '8px' 
                }}>
                  <Clock size={16} style={{ 
                    color: 'rgba(255, 255, 255, 0.5)',
                    flexShrink: 0
                  }} />
                  <span style={{ 
                    color: 'rgba(255, 255, 255, 0.8)', 
                    fontSize: '0.9rem' 
                  }}>
                    {new Date(claim.UploadedAt).toLocaleDateString('en-US', {
                      month: 'short',
                      day: 'numeric',
                      year: 'numeric',
                      hour: '2-digit',
                      minute: '2-digit'
                    })}
                  </span>
                </div>
                
                {/* Tags */}
                {claim.Tags.length > 0 && (
                  <div style={{ 
                    display: 'flex', 
                    flexWrap: 'wrap', 
                    gap: '4px', 
                    marginTop: '4px' 
                  }}>
                    {claim.Tags.map((tag, i) => (
                      <span key={i} style={{
                        padding: '2px 6px',
                        background: 'rgba(102, 126, 234, 0.15)',
                        color: '#a5b4fc',
                        borderRadius: '4px',
                        fontSize: '0.75rem',
                        border: '1px solid rgba(102, 126, 234, 0.25)',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '3px'
                      }}>
                        <Tag size={10} />
                        {tag}
                      </span>
                    ))}
                  </div>
                )}
              </div>
              
              {/* Size indicator */}
              <div style={{
                position: 'absolute',
                bottom: '1.5rem',
                right: '1.5rem',
                fontSize: '0.7rem',
                color: 'rgba(255, 255, 255, 0.3)'
              }}>
                {(claim.SizeBytes / 1024).toFixed(1)} KB
              </div>
            </div>
          ))}
        </div>
      )}

      <style>{`
        @keyframes spin {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
        
        @keyframes fadeInUp {
          from {
            opacity: 0;
            transform: translateY(10px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }
      `}</style>
    </div>
  );
}