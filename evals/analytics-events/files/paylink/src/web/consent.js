const KEY = 'paylink.analytics-consent';

// The consent banner. Shown by the merchant app shell on first visit; the
// answer is remembered in localStorage.
export function applyStoredConsent(analytics, storage) {
  const stored = storage.getItem(KEY);
  if (stored !== null) analytics.setConsent(stored === 'yes');
  return stored !== null;
}

export function answerConsent(analytics, storage, accepted) {
  storage.setItem(KEY, accepted ? 'yes' : 'no');
  analytics.setConsent(accepted);
  analytics.track('consent_updated', { analytics: accepted });
}

export function renderConsentBanner() {
  return `<div class="consent" role="dialog">
  <p>May we collect anonymous usage data to improve paylink?</p>
  <button data-consent="yes">Allow</button> <button data-consent="no">No thanks</button>
</div>`;
}
