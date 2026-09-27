import React from 'react';

// A tenant without a logo shows its display name as a wordmark.
export default function Header({ tenant }) {
  return (
    <header className="app-header">
      {tenant.logo ? (
        <img src={tenant.logo} alt={tenant.displayName} height="32" />
      ) : (
        <span className="wordmark">{tenant.displayName}</span>
      )}
    </header>
  );
}
