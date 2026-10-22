# Visual baselines

These PNGs use **Flutter 3.47.1 on Windows** with bundled Inter, Space Grotesk,
and Material Icons fonts. Keep the Flutter version in `.github/workflows/main.yml`
in sync when intentionally updating the baselines.

Native font rasterization and Flutter engine changes can produce pixel differences
across operating systems. `expectWindowsGolden` therefore compares pixels on
Windows only. All surrounding interaction, timing, layout, and accessibility
assertions still execute on Linux and other hosts.

The required **Windows visual regression tests** CI job runs `flutter test test/ui`
with exact pixel matching. The Linux job runs the full suite with coverage and
builds the APK only after the visual job passes. Neither job updates baselines
automatically or accepts a percentage of differing pixels.

To review an intentional visual change, use Windows with Flutter 3.47.1:

```powershell
flutter test --update-goldens test/ui
flutter test test/ui
```

Inspect each changed image before committing it. After a CI visual failure,
download the `windows-visual-diffs` artifact for expected, actual, and diff images.
Platform and SDK migrations need a deliberate baseline review.
