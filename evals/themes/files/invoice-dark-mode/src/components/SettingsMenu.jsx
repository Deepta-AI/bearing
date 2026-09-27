import React, { useState } from 'react';
import { getPref, setPref } from '../lib/prefs.js';

export default function SettingsMenu() {
  const [open, setOpen] = useState(false);
  const [density, setDensity] = useState(getPref('density', 'comfortable'));

  function changeDensity(value) {
    setDensity(value);
    setPref('density', value);
    document.documentElement.dataset.density = value;
  }

  return (
    <div className="settings">
      <button className="button" aria-expanded={open} onClick={() => setOpen(!open)}>Settings</button>
      {open && (
        <div className="card settings-panel" role="menu">
          <label>
            Density
            <select value={density} onChange={(e) => changeDensity(e.target.value)}>
              <option value="comfortable">Comfortable</option>
              <option value="compact">Compact</option>
            </select>
          </label>
        </div>
      )}
    </div>
  );
}
