// Design tokens for the app, and nowhere else. A hex literal in a component
// is a review finding; add the token instead.
//
// The names are the web lanes' role names (background, foreground,
// muted-foreground, primary, destructive, border), which react and
// nextjs declare as CSS variables in their global stylesheet because
// Tailwind v4 has no config file. NativeWind 4 compiles against Tailwind
// v3, so the mobile values live here as plain colours under the same names.
// A token renamed or added on one side is renamed or added on the other in
// the same change. NativeWind 5 reads Tailwind v4 `@theme` CSS; move to it
// when it leaves release candidate, and this file becomes global.css.
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./app/**/*.{ts,tsx}', './src/**/*.{ts,tsx}'],
  presets: [require('nativewind/preset')],
  theme: {
    extend: {
      colors: {
        background: { DEFAULT: '#ffffff', dark: '#111318' },
        foreground: { DEFAULT: '#1a1c22', dark: '#e8eaf0' },
        'muted-foreground': '#5c6270',
        primary: { DEFAULT: '#2f6fed', pressed: '#2258c4', foreground: '#ffffff' },
        destructive: '#c93a3a',
        border: { DEFAULT: '#d9dce3', dark: '#2a2e38' },
      },
    },
  },
  plugins: [],
};
