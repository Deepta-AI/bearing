import React from 'react';
import { createRoot } from 'react-dom/client';
import './styles/fonts.css';
import './styles/tokens.css';
import './styles/app.css';
import { applyTenant } from './theme/applyTenant.js';
import App from './App.jsx';

const tenant = applyTenant(window.location.hostname, document);
createRoot(document.getElementById('root')).render(<App tenant={tenant} />);
