#!/usr/bin/env bash
# tests/unit/motion_check.sh: skills/motion-design/scripts/motion_check.py
# counts animations across web CSS, web scripts, React Native, Compose and
# SwiftUI, and passes only when every one moves transform and opacity and
# has a reduced-motion path (in the file or a shared tokens module). It
# fails, with file:line, on each layout or paint property per stack, on an
# unguarded animation, and on empty input (no file, zero animations). The
# kit's own hero and banner templates pass.
set -u
. "$(dirname "$0")/../lib/assert.sh"
CHK="$KIT/skills/motion-design/scripts/motion_check.py"

# fixture <dir>: one clean file per stack plus a shared tokens module.
fixture() {
  mkdir -p "$1/src/styles" "$1/src/components" "$1/app" "$1/android" "$1/ios"
  cat > "$1/src/styles/tokens.css" <<'CSS'
:root { --duration-fast: 150ms; --duration-base: 240ms; --ease-enter: cubic-bezier(0, 0, 0.2, 1); }
@media (prefers-reduced-motion: reduce) {
  :root { --duration-fast: 0ms; --duration-base: 0ms; }
}
CSS
  cat > "$1/src/components/card.css" <<'CSS'
/* transition: width 1s; a comment is not an animation */
.card { transition: transform var(--duration-fast) var(--ease-enter), opacity var(--duration-base) ease-out; }
.card:hover { transition: background-color var(--duration-fast) linear; }
CSS
  cat > "$1/src/components/Sheet.tsx" <<'TSX'
import { motion, useReducedMotion } from "framer-motion";
export function Sheet() {
  const reduce = useReducedMotion();
  return <motion.div initial={{ opacity: 0, y: 24 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: reduce ? 0 : 0.24 }} />;
}
TSX
  cat > "$1/app/Pulse.tsx" <<'TSX'
import Animated, { useAnimatedStyle, withTiming, useReducedMotion } from "react-native-reanimated";
export function Pulse({ on }: { on: boolean }) {
  const reduce = useReducedMotion();
  const style = useAnimatedStyle(() => ({ opacity: withTiming(on ? 1 : 0.4), transform: [{ scale: withTiming(on ? 1 : 0.96) }] }));
  return <Animated.View style={style} />;
}
TSX
  cat > "$1/android/Badge.kt" <<'KT'
@Composable
fun Badge(visible: Boolean) {
    val reduced = LocalReducedMotion.current
    val alpha by animateFloatAsState(if (visible) 1f else 0f, label = "alpha")
    Box(Modifier.graphicsLayer { this.alpha = alpha })
}
KT
  cat > "$1/ios/Badge.swift" <<'SWIFT'
struct Badge: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var shown = false
    var body: some View {
        Circle().scaleEffect(shown ? 1 : 0.9).opacity(shown ? 1 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.24), value: shown)
    }
}
SWIFT
}
run() { python3 "$CHK" "$@"; }

t_begin "clean animations in every stack pass with their counts"
d="$(tmpdir)/ok"; fixture "$d"
assert_exit 0 run "$d"
assert_contains "$T_OUT" "motion-check: 6 files scanned, 6 animations, 0 properties outside transform and opacity, 0 without a reduced-motion path"
assert_not_contains "$T_OUT" "problem:"
t_end

t_begin "the kit's hero and banner templates pass"
assert_exit 0 run "$KIT/skills/motion-design/templates/hero.html" "$KIT/skills/motion-design/templates/banner.html"
assert_contains "$T_OUT" "0 properties outside transform and opacity, 0 without a reduced-motion path"
t_end

t_begin "web: width, transition all, a keyframes height and a styled template fail"
d="$(tmpdir)/web"; fixture "$d"
cat >> "$d/src/components/card.css" <<'CSS'
.panel { transition: width var(--duration-base) ease, opacity var(--duration-base); }
.menu { transition: all var(--duration-fast); }
@keyframes grow { from { height: 0; opacity: 0 } to { height: 200px; opacity: 1 } }
CSS
printf 'const Box = styled.div`\n  transition: margin-left 200ms ease;\n`;\nconst reduce = matchMedia("(prefers-reduced-motion: reduce)");\n' > "$d/src/components/Box.ts"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "card.css:4: transition animates width"
assert_contains "$T_OUT" "card.css:5: transition animates all"
assert_contains "$T_OUT" "card.css:6: @keyframes grow animates height"
assert_contains "$T_OUT" "Box.ts:2: transition animates margin-left"
assert_contains "$T_OUT" "card.css:6: @keyframes grow has no reduced-motion path"
assert_contains "$T_OUT" "4 properties outside transform and opacity, 1 without"
t_end

t_begin "scripts: a Web Animations height, a Framer width and RN without the native driver fail"
d="$(tmpdir)/js"; fixture "$d"
printf 'const r = matchMedia("(prefers-reduced-motion: reduce)");\nel.animate([{ height: "0px" }, { height: "80px" }], { duration: 200 });\n' > "$d/src/components/grow.js"
sed -i.bak 's/animate={{ opacity: 1, y: 0 }}/animate={{ opacity: 1, y: 0, width: 320 }}/' "$d/src/components/Sheet.tsx"
printf 'import { useReducedMotion } from "react-native-reanimated";\nAnimated.timing(v, { toValue: 1, duration: 200 }).start();\nLayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);\n' > "$d/app/Old.tsx"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "grow.js:2: .animate() animates height"
assert_contains "$T_OUT" "Sheet.tsx:4: animate= animates width"
assert_contains "$T_OUT" "Old.tsx:2: Animated.timing animates useNativeDriver off"
assert_contains "$T_OUT" "Old.tsx:3: LayoutAnimation animates layout"
t_end

t_begin "native: Compose animateContentSize and a Dp in a size modifier, SwiftUI frame fail"
d="$(tmpdir)/native"; fixture "$d"
cat >> "$d/android/Badge.kt" <<'KT'
@Composable
fun Grow(open: Boolean) {
    val reduced = LocalReducedMotion.current
    val h by animateDpAsState(if (open) 200.dp else 0.dp, label = "h")
    Column(Modifier.height(h).animateContentSize()) {}
}
KT
cat >> "$d/ios/Badge.swift" <<'SWIFT'
struct Drawer: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var open = false
    var body: some View {
        Rectangle().frame(height: open ? 200 : 0)
            .onTapGesture { withAnimation { open.toggle() } }
    }
}
SWIFT
assert_exit 1 run "$d"
assert_contains "$T_OUT" "Badge.kt:11: animateContentSize animates height"
assert_contains "$T_OUT" "Badge.kt:11: animated h animates height"
assert_contains "$T_OUT" "Badge.swift:13: animated open animates frame"
t_end

t_begin "an animation with no guard in the file or a shared module fails"
d="$(tmpdir)/guard"; fixture "$d"
printf '.toast { transition: opacity 200ms ease-out; }\n' > "$d/src/components/toast.css"
printf '@Composable\nfun Fade(v: Boolean) { val a by animateFloatAsState(if (v) 1f else 0f) }\n' > "$d/android/Fade.kt"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "toast.css:1: transition has no reduced-motion path"
assert_contains "$T_OUT" "Fade.kt:2: animateFloatAsState has no reduced-motion path"
assert_contains "$T_OUT" "0 properties outside transform and opacity, 2 without a reduced-motion path"
t_end

t_begin "a shared module guards by custom property, by a * reset and by import"
d="$(tmpdir)/shared"; mkdir -p "$d"
printf '.a { transition: opacity var(--duration-base); }\n' > "$d/a.css"
printf '.b { transition: opacity 200ms; }\n' > "$d/b.css"
printf '@media (prefers-reduced-motion: reduce) { :root { --duration-base: 0ms; } }\n' > "$d/vars.css"
assert_exit 1 run --shared "$d/vars.css" "$d/a.css" "$d/b.css"
assert_contains "$T_OUT" "b.css:1: transition has no reduced-motion path"
assert_not_contains "$T_OUT" "a.css:1"
printf '@media (prefers-reduced-motion: reduce) { *, *::before { transition-duration: 0.01ms !important; } }\n' > "$d/reset.css"
assert_exit 0 run --shared "$d/reset.css" "$d/a.css" "$d/b.css"
printf 'export const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;\n' > "$d/motion.ts"
printf 'import { reduce } from "./motion";\nel.animate({ opacity: [0, 1] }, { duration: reduce ? 0 : 200 });\n' > "$d/fade.ts"
assert_exit 0 run "$d/motion.ts" "$d/fade.ts"
assert_contains "$T_OUT" "motion-check: 2 files scanned, 1 animations, 0 properties"
t_end

t_begin "no file, a missing path and zero animations fail"
d="$(tmpdir)/empty"; mkdir -p "$d/src"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "0 files scanned, nothing checked"
assert_exit 1 run
assert_contains "$T_OUT" "0 files scanned, nothing checked"
printf '.plain { color: red; }\n' > "$d/src/plain.css"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "motion-check: 1 files scanned, 0 animations"
assert_contains "$T_OUT" "0 animations in 1 files, nothing checked"
fixture "$d"
assert_exit 1 run "$d" "$d/typo.css"
assert_contains "$T_OUT" "typo.css: no such file or directory"
t_end

t_summary
