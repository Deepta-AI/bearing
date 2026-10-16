# design-directions: the audit before designing

Read when you run step 2 and need each audit finding's full check.

2. Audit what the directions will sit on, before designing. Each finding
   goes in the output, even when it is outside the feature:
   - Colours outside the tokens: Grep the screens and the components they
     render for fixed palette classes (`bg-amber-50`, `text-sky-800`),
     hex, `rgb(` and `oklch(` literals and inline `style=`. No theme
     reaches them, and they usually stay light in dark mode.
   - Text tokens, frozen or not, against the project's contrast rule:
     compute every text colour on every surface it can sit on, and every
     label on its fill (white on a bright brand colour is the usual
     failure). A token that fails is not used for that role; name it.
   - Field edges and control boundaries need 3:1 against what surrounds
     them (WCAG 1.4.11); a pale line token rarely has it.
   - Target sizes as rendered: read the component's real height (`h-9`
     is 36 px) and check inline elements, where `min-height` does nothing
     on an `a` that is not a block or flex box.
   - Fonts: does anything load the faces the tokens name (an
     `@font-face`, a Fontsource import, a file under `public/` or
     `static/`)? A face that is named but never loaded renders as the
     fallback everywhere.
   - Privacy: does a live screen or sample show what the flows forbid (a
     typed birth year in plain view, a full name, a reason for a visit)?
