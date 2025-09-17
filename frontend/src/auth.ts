import { Amplify } from 'aws-amplify';

// Pull from Vite env (must start with VITE_)
const {
  VITE_USER_POOL_ID,
  VITE_USER_POOL_CLIENT_ID,
  VITE_COGNITO_DOMAIN,
  VITE_REDIRECT_URI,
} = import.meta.env as Record<string, string>;

// Amplify v6 expects the domain *without* scheme and without trailing slash
const oauthDomain = (VITE_COGNITO_DOMAIN || '')
  .replace(/^https?:\/\//, '')
  .replace(/\/$/, '');

Amplify.configure({
  Auth: {
    Cognito: {
      userPoolId: VITE_USER_POOL_ID,
      userPoolClientId: VITE_USER_POOL_CLIENT_ID,
      // Optional, but nice to be explicit:
      signUpVerificationMethod: 'code',
      loginWith: {
        // We’ll use Hosted UI; you can still allow email login in Authenticator
        email: true,
        username: false,
        oauth: {
          domain: oauthDomain,
          scopes: ['openid', 'email', 'profile'],
          redirectSignIn: [VITE_REDIRECT_URI],
          redirectSignOut: [VITE_REDIRECT_URI],
          responseType: 'code',
        },
      },
    },
  },
});
