/**
 * THEME_SCRIPT runs in <head> before the first paint, so a visitor whose
 * system is dark never sees a light flash, and a screenshot taken before
 * hydration shows the right theme. Order: ?theme= (the design gallery and
 * review shots), then the visitor's saved choice, then the system setting.
 * ?variant= applies a design direction in the gallery; its CSS is loaded
 * only there. The Content-Security-Policy allows this script by its hash.
 */
export const THEME_SCRIPT = `(function(){try{var r=document.documentElement,q=new URLSearchParams(location.search),t=q.get("theme")||localStorage.getItem("theme"),d=t?t==="dark":matchMedia("(prefers-color-scheme: dark)").matches;r.classList.toggle("dark",d);var v=q.get("variant");if(v&&/^[0-9]+-[a-z0-9-]+$/.test(v))r.dataset.variant=v}catch(e){}})()`;
