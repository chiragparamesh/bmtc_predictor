# CLAUDE.md — BMTC Delay Predictor (`bmtc_predictor`)

Context for future Claude Code sessions. Read this before changing anything.

Owner: Chirag (final-year AIML engineering student). This is a resume project.
GitHub: https://github.com/chiragparamesh/bmtc_predictor (public). Org / package: `com.chirag.bmtc_predictor`.

## Project brief

### 2. bmtc_predictor — "BMTC Delay Predictor" (resume project)

**Problem:** BMTC bus arrival times in Bengaluru are unreliable.

**Vision:** use the community BMTC GTFS feed (github.com/Vonter/bmtc-gtfs) and Open-Meteo rainfall data to predict delay per stop. XGBoost baseline, then a graph neural network over the stop network so delays propagate to later stops, with quantile predictions ("90% chance it arrives by 8:42"), crowd levels, a "best time to leave" suggestion, and Kannada/English UI. Ground truth is collected through user "bus arrived" reports.

**Current build scope:** bundled subset of busy routes (Silk Board, ORR, Majestic), stop search, scheduled times, predicted delay from a small model exported from Colab, rain mode toggle, "bus arrived" report button stored locally.

## Lightweight rules

My Windows laptop has low RAM: Android Studio and the Android emulator froze it. Everything must stay lightweight:

- No Android Studio, no emulator, no local Gradle/APK builds.
- Daily preview with: `flutter run -d chrome`
- APKs are built by GitHub Actions and installed on my Pixel 9a.
- ML models are trained in Google Colab; only the exported .tflite files live in the project.
- Everything goes inside `D:\Projects`. Nothing else on `D:\` root.
- Never run Gradle or `flutter build apk` locally.
- One install / one heavy task at a time. Never run parallel heavy tasks.
- `android/gradle.properties` stays capped: `org.gradle.jvmargs=-Xmx1536m`, `org.gradle.daemon=false`, `org.gradle.parallel=false`.
- Toolchain lives in `D:\Projects\_tools` (flutter, jdk, android-sdk, caches\pub, caches\gradle).

## How to work in this repo

- Preview: `flutter run -d chrome` (web is the dev target; Android is built only by CI).
- Checks you may run locally: `flutter pub get`, `flutter analyze`, `flutter test`.
- Never run: `flutter build apk`, `./gradlew`, `flutter run -d <android device>` with a local build, or anything that starts Gradle.
- APK: push to GitHub → Actions → "Build APK" → download the `bmtc_predictor-release-apk` artifact → install on the Pixel 9a.
- Plugins that don't support web (camera, tflite, GPS, haptics, …) must sit behind an interface in `lib/core/services/` with a web/mock implementation so Chrome preview keeps working.

## Structure

- `lib/main.dart`, `lib/app.dart` — entry point and `MaterialApp.router`.
- `lib/core/theme/` — theme and colors. `lib/core/router/` — go_router routes.
- `lib/core/services/` — platform/service interfaces. `lib/core/utils/` — constants, helpers. `lib/core/widgets/` — shared widgets.
- `lib/features/<feature>/{data,domain,presentation}/` — one folder per feature:
  - `lib/features/stop_search/` — Home: stop search (EN/Kannada), recent + popular stops
  - `lib/features/schedule/` — `Network` (assets/data/network.json): arrivals per stop, trip timelines; stop + trip screens
  - `lib/features/prediction/` — `DelayModel` (Dart MLP from assets/models/delay_model.json), `delayFeatures()`, `ModelDelayPredictor` (+ report correction)
  - `lib/features/rain_mode/` — Rain mode toggle feeding the model
  - `lib/features/arrival_report/` — "Bus arrived" report button, stored locally
- `ml/` — `train_delay_model.py` + Colab notebook. Exports `assets/models/delay_model.json` (JSON MLP weights, not .tflite: see ml/README.md).
- `docs/architecture.md` — full system design and roadmap. Keep it updated.
- `.github/workflows/build-apk.yml` — the only place APKs are built.

## Status

Phase 1 built (see README features table): 12-route GTFS subset, stop search EN/ಕನ್ನಡ, scheduled + expected +
"90% by" times, trip timeline, rain mode, "Bus arrived" reports with on-device correction, reports scorecard + CSV export.
Model v0 is trained on a documented traffic prior (no public arrival data exists); README says so.
Next: live Open-Meteo rain, collect reports, XGBoost baseline, then GNN (docs/architecture.md).

## Conventions

- Times: IST wall-clock DateTimes stored as UTC (`core/utils/ist_time.dart`); `clockProvider` gives "now" (override in tests).
- Feature contract: `delayFeatures()` in Dart MUST match `features()` in ml/train_delay_model.py (same order, scaling).
  After retraining, `flutter test` checks Dart/Python parity using `checks` in delay_model.json.
- Rebuild the subset: `python ml/tools/build_network.py <unzipped gtfs dir> assets/data/network.json` (`ml/tools/build_network.py`; unzip the GTFS from Vonter/bmtc-gtfs first).
- State: Riverpod; prefs-backed settings use `BoolSetting` (core/services/settings.dart).
- Widget tests: `rootBundle.clear()` in setUp and the `_settle` helper (assets load on a background isolate).
- Data licence: network.json is ODbL 1.0 (Vonter/bmtc-gtfs); keep the attribution in README.
- Run `flutter analyze` and `flutter test` before every push. Update the README features table as features land.
