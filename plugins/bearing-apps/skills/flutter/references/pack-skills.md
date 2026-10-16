# flutter: pack skills

Read when a layout, deep-link or widget-test job could use a skill from the Flutter team's agent-plugins pack.

The Flutter team's agent-plugins pack covers three narrow jobs that this
lane uses it for. When one of the three is installed, load it with the Skill tool for that job; when it is not, do
the job from this lane's references and name the missing skill.

- `flutter-fix-layout-issues`: a RenderFlex overflow, an unbounded height
  or width, or an `Expanded` or `Positioned` in the wrong parent.
- `flutter-setup-declarative-routing`: the platform half of deep links
  (Android intent filter and assetlinks.json, iOS associated domains and
  apple-app-site-association). Routes stay named and parameters are
  validated; ignore its string-path `context.go` examples.
- `flutter-add-widget-test`: `WidgetTester` mechanics (finders, `pump`
  against `pumpAndSettle`, scrolling a lazy list). This lane still decides
  what a screen test covers: loading, error and data, inside a
  `ProviderScope` with overrides and the localisation delegates.

Not loaded here: `flutter-apply-architecture-best-practices`
(`ChangeNotifier` view models; only for a repository already built that
way), `flutter-setup-localization` (deprecated synthetic `flutter_gen`),
`flutter-add-integration-test` (puts a driver extension in the entry
point) and `dart-run-static-analysis` (a subset of `make check`).
