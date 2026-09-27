import { track } from '../analytics.js';
import { assign } from '../assign.js';

const EXPERIMENT = 'free-shipping-banner';

// ctx: { deviceId, product, onImageLoad(src, fn) } supplied by the page shell.
export function renderProductPage(ctx) {
  const variant = assign(ctx.deviceId, EXPERIMENT, 50);
  const exposed = () =>
    track('experiment_exposed', { experiment: EXPERIMENT, variant, device_id: ctx.deviceId, platform: 'web' });

  let banner = '';
  if (variant === 'treatment') {
    banner = '<img class="banner" src="/img/free-shipping-banner.png" alt="Free shipping over 499">';
    // Count the visitor only once the banner has actually been seen.
    ctx.onImageLoad('/img/free-shipping-banner.png', exposed);
  } else {
    exposed();
  }
  return `<main>${banner}<h1>${ctx.product.name}</h1><button>Add to cart</button></main>`;
}
