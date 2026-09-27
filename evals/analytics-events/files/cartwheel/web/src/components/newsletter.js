// Footer newsletter form.
export async function subscribe(api, email) {
  await api.post('/api/newsletter', { email });
  navigator.sendBeacon('/collect', JSON.stringify({ event: 'newsletter_subscribed', props: { email } }));
}
