# Accessibility checklist

WCAG 2.2 AA for web. Platform guidelines for mobile, mapped to the same
criteria so one report format covers all four stacks. Each line names the
criterion, the grep that finds candidates, and the fix.

## Web (SPA or server-rendered templates, WCAG 2.2 AA)

| Criterion | Grep | Fix |
| --- | --- | --- |
| 1.1.1 Non-text content | `<img` without `alt=`; `<svg` in a button without `aria-hidden` | `alt` that says what the image is for; `alt=""` and `aria-hidden` when decorative |
| 1.3.1 Info and relationships | `<input` without `<label` or `aria-labelledby`; `placeholder=` as the only name; radios or cards without `fieldset`/`legend`; a table without `<th` | Visible `label for`; `fieldset` and `legend` around native radios; `th` with `scope` |
| 1.3.5 Input purpose | `name="name"`, `type="email"`, `type="password"`, `tel`, address fields without `autocomplete` | `autocomplete="name"`, `email`, `new-password`, `tel` |
| 1.4.3 Contrast | colour tokens in `src/index.css`; `text-gray-400`, `text-muted` on light backgrounds | 4.5:1 body, 3:1 large text and UI parts; measure the rendered pair |
| 1.4.11 Non-text contrast | focus rings, input borders, toggle tracks, icons under 3:1 (a field border is not decorative when it is the field's only boundary) | Measure with `scripts/contrast.py`; a darker border or a filled field |
| 2.1.1 Keyboard | `onClick` on `div` or `span`; `tabIndex={-1}` on a control | Native `button`, `a`, `input` |
| 2.4.3 Focus order | `tabIndex` above 0; DOM order differs from visual order | Remove positive `tabIndex`; reorder the DOM |
| 3.1.1 Language of page | `<html` without `lang` | `lang="en"` (the page's language) |
| 2.4.7 Focus visible | `outline-none`, `outline: none` without a `:focus-visible` replacement | `:focus-visible` ring at 3:1 |
| 2.4.11 Focus not obscured | sticky headers and toasts over the focused control | `scroll-margin-top`; toasts outside the flow |
| 2.5.8 Target size | buttons and links under 24 by 24 px (`width: 20px` icon buttons) | Padding or `min-h-6 min-w-6` |
| 2.5.3 Label in name | `aria-label` on an element with visible text | Remove it, or start it with the visible text |
| 3.3.1 Error identification | error text not linked with `aria-describedby`; no `aria-invalid`; a server-rendered error page with the same `title` | Link the message from each control (each radio in a group); `aria-invalid`; "Error:" in the title and a summary at the top |
| 3.3.4 Error prevention | money, legal or deleting submissions with no review, confirm or undo | A review step or an undo |
| 4.1.2 Name, role, value | icon-only `button` without `aria-label`; custom toggle without `aria-pressed` or `aria-checked` | `aria-label` from the visible copy; the right state attribute |
| 4.1.3 Status messages | loading and result regions without `role="status"` or `aria-live` | `role="status"` on the region that changes |
| Dialogs | a modal without focus trap and return; `&times;` close buttons | `dialog` with `showModal()` (or the design system's dialog); return focus to the opener; a named close button |
| Without JavaScript | `href="#"`; controls that exist only through a script | A real link target; native controls |

Keyboard-only pass, per route: Tab reaches every control in reading order;
Enter and Space activate; Escape closes any dialog and focus returns; no
control is reachable only by hover; a skip link precedes the navigation.

### Axe spec pattern (`e2e/a11y.spec.ts`)

```ts
import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

// The API is mocked with page.route like every other spec.
const routes = ["/", "/login", "/nowhere"];

for (const route of routes) {
  test(`TC-nnnn ${route} has no WCAG 2.2 AA violations`, async ({ page }) => {
    await page.goto(route);

    const results = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa"])
      .analyze();

    expect(results.violations, JSON.stringify(results.violations, null, 2)).toEqual([]);
  });
}
```

The test fails on zero routes: keep `routes` non-empty and assert
`routes.length > 0` in a `test.beforeAll` when the list is generated.

## React Native

| Criterion | Grep | Fix |
| --- | --- | --- |
| Role | `Pressable`, `TouchableOpacity` without `accessibilityRole` | `accessibilityRole="button"` (or `link`, `switch`, `checkbox`) |
| Name | icon-only pressables without `accessibilityLabel` | Label from the visible copy or the design |
| State | toggles without `accessibilityState` | `{ checked }`, `{ selected }`, `{ disabled }` |
| Target | hit area under 44 pt (iOS) or 48 dp (Android) | `hitSlop` so the total reaches 48, or `minWidth`/`minHeight` 48 |
| Live regions | status and error text that appears after an action | `accessibilityLiveRegion="polite"` (Android only) plus `AccessibilityInfo.announceForAccessibility` or `accessibilityRole="alert"` for iOS |
| Masked values | `"••••"` or `***` as text | `accessibilityLabel` such as "Balance hidden" |
| Grouping | list rows of several `Text` nodes inside a `Pressable` | One element: `accessibilityRole`, a combined `accessibilityLabel` |
| Charts | bars or lines drawn from `View`s | `accessible` with a label built from the data |
| Orientation (1.3.4) | `"orientation": "portrait"` in `app.json` | `default`, unless the orientation is essential |
| Error prevention (3.3.4) | a send, pay or delete action with no review step | A confirm or review screen |
| Images | `Image` without `accessibilityLabel` or `accessible={false}` | Label, or hide when decorative |
| Text scaling | `allowFontScaling={false}` (also set app-wide through `defaultProps`); fixed heights around text | Remove; `minHeight` for fixed heights; `maxFontSizeMultiplier` on one element if it must be capped |

Manual on a device: VoiceOver and TalkBack read every screen in order; the
largest text size does not clip.

## Android (Compose, Material 3)

| Criterion | Grep | Fix |
| --- | --- | --- |
| Name | `Image(`, `Icon(` without `contentDescription` | Description from the string resource; `null` only when decorative |
| Role | `Modifier.clickable` without `role =` | `role = Role.Button` (or `Switch`, `Checkbox`) |
| Custom controls | drawn controls without `Modifier.semantics` | `semantics { contentDescription; stateDescription; role }` |
| Text scaling | text sizes in `.dp` | `.sp`; no fixed height on text containers |
| Target | touch targets under 48 dp | `Modifier.minimumInteractiveComponentSize()` |
| Live regions | status text without `liveRegion` | `Modifier.semantics { liveRegion = LiveRegionMode.Polite }` |
| Grouping | rows read as separate nodes | `Modifier.semantics(mergeDescendants = true)` |

Manual on a device: TalkBack traversal order; the Accessibility Scanner
report at the largest font and display size.

## iOS (SwiftUI)

| Criterion | Grep | Fix |
| --- | --- | --- |
| Name | `Button`, `Image` without `.accessibilityLabel` | Label from `Localizable.xcstrings` |
| Decorative | decorative images not `.accessibilityHidden(true)` | Hide them |
| Dynamic Type | `.font(.system(size:` | `.font(.body)` and the other text styles; `@ScaledMetric` for spacing |
| Clipping | `.frame(height:` around text; `lineLimit(1)` on body copy | Remove the fixed frame; test at the largest accessibility size |
| Grouping | rows with several labels | `.accessibilityElement(children: .combine)` |
| State | custom toggles without `.accessibilityValue` or `.accessibilityAddTraits(.isSelected)` | Add the value or trait |
| Announcements | status changes without `AccessibilityNotification.Announcement` | Post the announcement |

Manual on a device: VoiceOver reads every screen in order; the largest
accessibility size in the Accessibility Inspector; Reduce Motion honoured.

## Severity mapping

- Critical: a flow cannot be completed by keyboard or with a screen reader.
- High: a WCAG level A criterion fails (1.1.1, 1.3.1, 2.1.1, 4.1.2).
- Medium: a level AA criterion fails (1.4.3, 1.4.11, 2.4.7, 2.5.8, 4.1.3).
- Low: a best practice with no criterion behind it.
