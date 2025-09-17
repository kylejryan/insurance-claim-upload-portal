import React, { useEffect, useState } from 'react';
import { Authenticator, View, Button, ThemeProvider } from '@aws-amplify/ui-react';
import '@aws-amplify/ui-react/styles.css';
import './auth';
import { listClaims, type Claim } from './api';
import UploadForm from './components/UploadForm';
import ClaimList from './components/ClaimList';

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

  return (
    <ThemeProvider>
      <Authenticator socialProviders={[]} variation="modal">
        {({ signOut, user }) => (
          <View padding="1rem" maxWidth="900px" margin="0 auto" style={{ display:'grid', gap:24 }}>
            <header style={{ display:'flex', justifyContent:'space-between', alignItems:'center' }}>
              <h1>Claims Portal</h1>
              <div>
                <span style={{ marginRight: 8 }}>{user?.signInDetails?.loginId}</span>
                <Button variation="link" onClick={signOut}>Sign out</Button>
              </div>
            </header>

            <UploadForm onUploaded={() => setTimeout(refresh, 700)} />
            <ClaimList claims={claims} loading={loading} refresh={refresh} />
          </View>
        )}
      </Authenticator>
    </ThemeProvider>
  );
}

