import React, { useEffect, useState } from 'react';
import { Authenticator, View, Button, ThemeProvider } from '@aws-amplify/ui-react';
import '@aws-amplify/ui-react/styles.css';
import './auth';
import { listClaims, type Claim } from './api';
import UploadForm from './components/UploadForm';
import ClaimList from './components/ClaimList';
import { Shield, LogOut, User, TrendingUp, CheckCircle2, Clock } from 'lucide-react';

// Custom modern theme for Amplify UI
const modernTheme = {
  name: 'modern-dark',
  tokens: {
    colors: {
      background: {
        primary: { value: '#0a0a0f' },
        secondary: { value: '#141420' },
        tertiary: { value: 'rgba(255, 255, 255, 0.05)' },
      },
      font: {
        primary: { value: 'rgba(255, 255, 255, 0.95)' },
        secondary: { value: 'rgba(255, 255, 255, 0.7)' },
        tertiary: { value: 'rgba(255, 255, 255, 0.5)' },
      },
      brand: {
        primary: {
          10: { value: '#f0f9ff' },
          20: { value: '#e0f2fe' },
          40: { value: '#7dd3fc' },
          60: { value: '#38bdf8' },
          80: { value: '#667eea' },
          90: { value: '#764ba2' },
          100: { value: '#5a4580' },
        },
      },
      border: {
        primary: { value: 'rgba(255, 255, 255, 0.1)' },
        secondary: { value: 'rgba(255, 255, 255, 0.2)' },
        tertiary: { value: 'rgba(102, 126, 234, 0.3)' },
      },
    },
    space: {
      small: { value: '0.5rem' },
      medium: { value: '1rem' },
      large: { value: '2rem' },
      xl: { value: '3rem' },
    },
    radii: {
      small: { value: '8px' },
      medium: { value: '12px' },
      large: { value: '20px' },
      xl: { value: '24px' },
    },
    shadows: {
      small: { value: '0 2px 4px rgba(0, 0, 0, 0.1)' },
      medium: { value: '0 4px 6px rgba(0, 0, 0, 0.1)' },
      large: { value: '0 10px 25px rgba(102, 126, 234, 0.3)' },
    },
  },
};

export default function App() {
  const [claims, setClaims] = useState<Claim[]>([]);
  const [loading, setLoading] = useState(false);

  const refresh = async () => {
    setLoading(true);
    try {
      const data = await listClaims();
      setClaims(data.items ?? []);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { refresh(); }, []);

  // Calculate statistics
  const totalClaims = claims.length;
  const completeClaims = claims.filter(c => c.Status === 'COMPLETE').length;
  const pendingClaims = claims.filter(c => c.Status === 'UPLOADING').length;

  return (
    <ThemeProvider theme={modernTheme}>
      <style>{`
        /* Global styles for modern look */
        body {
          background: linear-gradient(135deg, #0a0a0f 0%, #1a1a2e 100%);
          min-height: 100vh;
          margin: 0;
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Inter', sans-serif;
        }

        /* Animated background */
        .animated-bg::before {
          content: '';
          position: fixed;
          top: -50%;
          left: -50%;
          width: 200%;
          height: 200%;
          background: radial-gradient(circle at 20% 50%, rgba(120, 119, 198, 0.3) 0%, transparent 50%),
                      radial-gradient(circle at 80% 80%, rgba(255, 119, 198, 0.2) 0%, transparent 50%),
                      radial-gradient(circle at 40% 20%, rgba(119, 198, 255, 0.2) 0%, transparent 50%);
          animation: floatBackground 20s ease-in-out infinite;
          pointer-events: none;
          z-index: -1;
        }

        @keyframes floatBackground {
          0%, 100% { transform: rotate(0deg) scale(1); }
          50% { transform: rotate(180deg) scale(1.1); }
        }

        @keyframes fadeIn {
          from { opacity: 0; transform: translateY(20px); }
          to { opacity: 1; transform: translateY(0); }
        }

        @keyframes slideDown {
          from { opacity: 0; transform: translateY(-20px); }
          to { opacity: 1; transform: translateY(0); }
        }

        /* Custom Amplify Authenticator overrides */
        [data-amplify-authenticator] {
          --amplify-colors-background-primary: rgba(255, 255, 255, 0.05);
          --amplify-colors-background-secondary: rgba(255, 255, 255, 0.08);
          --amplify-colors-border-primary: rgba(255, 255, 255, 0.1);
          --amplify-colors-brand-primary-80: #667eea;
          --amplify-colors-brand-primary-90: #764ba2;
          --amplify-colors-brand-primary-100: #5a4580;
          --amplify-colors-font-primary: rgba(255, 255, 255, 0.95);
          backdrop-filter: blur(20px);
          border-radius: 24px;
          border: 1px solid rgba(255, 255, 255, 0.1);
          animation: fadeIn 0.6s ease-out;
        }

        .amplify-button--primary {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          border: none;
          border-radius: 12px;
          font-weight: 600;
          transition: all 0.3s ease;
        }

        .amplify-button--primary:hover {
          transform: translateY(-2px);
          box-shadow: 0 10px 25px rgba(102, 126, 234, 0.3);
        }

        .amplify-input {
          background: rgba(255, 255, 255, 0.05);
          border: 1px solid rgba(255, 255, 255, 0.1);
          color: rgba(255, 255, 255, 0.9);
          border-radius: 12px;
        }

        .amplify-input:focus {
          border-color: rgba(102, 126, 234, 0.5);
          background: rgba(255, 255, 255, 0.08);
          box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }

        /* Animation for components */
        .stats-card {
          animation: slideDown 0.5s ease-out;
          animation-fill-mode: both;
        }

        .stats-card:nth-child(1) { animation-delay: 0.1s; }
        .stats-card:nth-child(2) { animation-delay: 0.2s; }
        .stats-card:nth-child(3) { animation-delay: 0.3s; }

        .main-grid > * {
          animation: fadeIn 0.6s ease-out;
          animation-fill-mode: both;
        }

        .main-grid > *:nth-child(1) { animation-delay: 0.4s; }
        .main-grid > *:nth-child(2) { animation-delay: 0.5s; }
      `}</style>

      <div className="animated-bg" style={{ minHeight: '100vh', position: 'relative' }}>
        <Authenticator socialProviders={[]} variation="modal">
          {({ signOut, user }) => (
            <View 
              padding="2rem" 
              maxWidth="1400px" 
              margin="0 auto" 
              style={{ 
                position: 'relative',
                zIndex: 1
              }}
            >
              {/* Modern Header */}
              <header style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                padding: '2rem',
                background: 'rgba(255, 255, 255, 0.05)',
                backdropFilter: 'blur(10px)',
                borderRadius: '20px',
                border: '1px solid rgba(255, 255, 255, 0.1)',
                marginBottom: '2rem',
                animation: 'slideDown 0.5s ease-out'
              }}>
                <h1 style={{
                  fontSize: '2rem',
                  fontWeight: '800',
                  background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                  WebkitBackgroundClip: 'text',
                  WebkitTextFillColor: 'transparent',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '12px',
                  margin: 0
                }}>
                  <Shield size={32} />
                  Claims Portal
                </h1>
                
                <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                  <div style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px',
                    padding: '0.5rem 1rem',
                    background: 'rgba(255, 255, 255, 0.05)',
                    borderRadius: '12px',
                    border: '1px solid rgba(255, 255, 255, 0.1)'
                  }}>
                    <User size={18} style={{ color: 'rgba(255, 255, 255, 0.7)' }} />
                    <span style={{ color: 'rgba(255, 255, 255, 0.9)', fontSize: '0.9rem' }}>
                      {user?.signInDetails?.loginId || user?.username}
                    </span>
                  </div>
                  <Button 
                    variation="primary"
                    onClick={signOut}
                    style={{
                      background: 'rgba(239, 68, 68, 0.1)',
                      color: '#ef4444',
                      border: '1px solid rgba(239, 68, 68, 0.2)',
                      borderRadius: '8px',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '6px',
                      padding: '8px 16px',
                      fontSize: '0.9rem'
                    }}
                  >
                    <LogOut size={18} />
                    Sign Out
                  </Button>
                </div>
              </header>

              {/* Statistics Bar */}
              <div style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
                gap: '1.5rem',
                marginBottom: '2rem'
              }}>
                <div className="stats-card" style={{
                  padding: '1.5rem',
                  background: 'rgba(255, 255, 255, 0.05)',
                  backdropFilter: 'blur(10px)',
                  borderRadius: '16px',
                  border: '1px solid rgba(255, 255, 255, 0.1)',
                  transition: 'all 0.3s ease'
                }}>
                  <div style={{
                    color: 'rgba(255, 255, 255, 0.6)',
                    fontSize: '0.875rem',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                    marginBottom: '8px'
                  }}>
                    <TrendingUp size={16} />
                    Total Claims
                  </div>
                  <div style={{
                    fontSize: '2rem',
                    fontWeight: '700',
                    background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                    WebkitBackgroundClip: 'text',
                    WebkitTextFillColor: 'transparent'
                  }}>
                    {totalClaims}
                  </div>
                </div>

                <div className="stats-card" style={{
                  padding: '1.5rem',
                  background: 'rgba(255, 255, 255, 0.05)',
                  backdropFilter: 'blur(10px)',
                  borderRadius: '16px',
                  border: '1px solid rgba(255, 255, 255, 0.1)',
                  transition: 'all 0.3s ease'
                }}>
                  <div style={{
                    color: 'rgba(255, 255, 255, 0.6)',
                    fontSize: '0.875rem',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                    marginBottom: '8px'
                  }}>
                    <CheckCircle2 size={16} />
                    Complete
                  </div>
                  <div style={{
                    fontSize: '2rem',
                    fontWeight: '700',
                    color: '#22c55e'
                  }}>
                    {completeClaims}
                  </div>
                </div>

                <div className="stats-card" style={{
                  padding: '1.5rem',
                  background: 'rgba(255, 255, 255, 0.05)',
                  backdropFilter: 'blur(10px)',
                  borderRadius: '16px',
                  border: '1px solid rgba(255, 255, 255, 0.1)',
                  transition: 'all 0.3s ease'
                }}>
                  <div style={{
                    color: 'rgba(255, 255, 255, 0.6)',
                    fontSize: '0.875rem',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                    marginBottom: '8px'
                  }}>
                    <Clock size={16} />
                    Pending
                  </div>
                  <div style={{
                    fontSize: '2rem',
                    fontWeight: '700',
                    color: '#fbbf24'
                  }}>
                    {pendingClaims}
                  </div>
                </div>
              </div>

              {/* Main Content Grid */}
              <div className="main-grid" style={{
                display: 'grid',
                gridTemplateColumns: window.innerWidth > 1024 ? '1fr 2fr' : '1fr',
                gap: '2rem'
              }}>
                <UploadForm onUploaded={() => setTimeout(refresh, 700)} />
                <ClaimList claims={claims} loading={loading} refresh={refresh} />
              </div>
            </View>
          )}
        </Authenticator>
      </div>
    </ThemeProvider>
  );
}