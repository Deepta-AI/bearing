# react-native: NativeWind tokens and the folder layout

Read when you style a component, change a design token, or place a new file.

NativeWind over `StyleSheet`: design tokens live in one `tailwind.config.js`
under the role names the web lanes use (`background`, `foreground`,
`primary`, `destructive`, `border`), dark mode and platform variants are
class prefixes instead of branches, and it compiles to `StyleSheet` at
build time so there is no runtime cost. The web lanes are on Tailwind v4,
which has no config file: their tokens are CSS variables in the global
stylesheet. NativeWind 4 still compiles against Tailwind v3, so the two
files share names, not a file; a token changed on one side changes on the
other in the same MR. `StyleSheet` is still right for one-off
animated or measured styles.

## Layout

```
app/_layout.tsx                 root providers: QueryClient, SafeArea, Stack
app/<route>.tsx                 expo-router screens; a screen wires hooks to components
src/features/<feature>/api.ts   fetch calls that return Zod-parsed types
src/features/<feature>/schemas.ts  Zod schemas and the types derived from them
src/features/<feature>/hooks.ts    useQuery / useMutation wrappers, query keys
src/features/<feature>/components/ feature screens' building blocks
src/components/                 shared presentational components
src/lib/                        api client, query client, secure store, stores
assets/                         fonts, images, splash; nothing generated
.maestro/                       one flow per user-facing journey
Makefile                        the only entry point: help setup dev check fix test doctor
```
