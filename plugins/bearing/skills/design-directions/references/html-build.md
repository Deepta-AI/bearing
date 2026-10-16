# design-directions: the HTML variant build

Read when the target is not react-shadcn (step 7).

7. HTML targets. Build `<n>-<name>.html` per variant from
   `templates/variant.html`: tokens on `:root`, the screens as sections
   with the flows' copy word for word including the state screen, at the
   project's sizes (the device size and orientation when fixed; else no
   horizontal scroll at 375, 768 and 1440 and no half-width desktop
   column beside dead space), dark only when the product has dark,
   `:focus-visible` on every control, the motion moment behind the
   reduced-motion guard and inside the project's limit, the theme toggle
   as the only script. Fonts load the way the product can load them: a
   Google Fonts link only when no constraint forbids it and the device
   can reach it; otherwise self-hosted, or the fallback stated. Sample
   data follows the flows' privacy rules, and a sensitive input shows no
   typed value in plain view. Copy not in the flows is written and marked
   `proposed`.
