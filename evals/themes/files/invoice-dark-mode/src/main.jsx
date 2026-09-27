import React from 'react';
import { createRoot } from 'react-dom/client';
import './styles/tokens.css';
import './styles/app.css';
import './styles/print.css';
import { getPref } from './lib/prefs.js';
import App from './App.jsx';

document.documentElement.dataset.density = getPref('density', 'comfortable');

createRoot(document.getElementById('root')).render(<App />);
