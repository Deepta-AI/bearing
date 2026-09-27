const SCREENS = {
  '/': 'home',
  '/cart': 'cart',
  '/checkout': 'checkout',
  '/order/confirmed': 'order_confirmation',
};

export function onNavigate(analytics, path) {
  const screen = path.startsWith('/p/') ? 'product' : SCREENS[path];
  if (screen) analytics.screen(screen);
}
