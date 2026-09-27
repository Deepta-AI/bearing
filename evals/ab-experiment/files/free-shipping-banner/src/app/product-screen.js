import { track } from '../analytics.js';
import { assign } from '../assign.js';

const EXPERIMENT = 'free-shipping-banner';

// The app bundles the banner, so it is on screen as soon as the screen mounts.
export function productScreen(ctx) {
  const variant = assign(ctx.deviceId, EXPERIMENT, 50);
  track('experiment_exposed', { experiment: EXPERIMENT, variant, device_id: ctx.deviceId, platform: 'app' });
  return {
    banner: variant === 'treatment' ? 'free-shipping-banner' : null,
    title: ctx.product.name,
  };
}
