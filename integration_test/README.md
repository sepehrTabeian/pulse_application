# integration_test/

`app_flow_test.dart` runs the real app on a **real Android emulator or device** (phone or tablet) with the real
container and the `pulse_api` simulator.

```bash
flutter test integration_test -d <device-id>      # see `flutter devices`
```

The same file adapts to the window class: a tablet must show two panes, a phone pushes the ticket full screen.

## Status
These tests have **not** run on an emulator yet: the Gradle build fails offline at `:app:checkDebugAarMetadata` because
`androidx.test` artifacts are not reachable (details in `docs/PROGRESS.md`). Run them on a machine with working Google
Maven access, or with a pre-populated Gradle cache. Fix any failure before relying on this folder.
