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
  - `lib/features/stop_search/` — Search stops on the bundled busy routes
  - `lib/features/schedule/` — Scheduled times from the GTFS subset
  - `lib/features/prediction/` — Predicted delay from the Colab-exported model
  - `lib/features/rain_mode/` — Rain mode toggle feeding the model
  - `lib/features/arrival_report/` — "Bus arrived" report button, stored locally
- `ml/` — Colab workflow notes. Only exported `.tflite` files are committed, in `assets/models/`.
- `docs/architecture.md` — full system design and roadmap. Keep it updated.
- `.github/workflows/build-apk.yml` — the only place APKs are built.

## Status

Skeleton only: folders, theme, router, placeholder home screen, CI. No features built yet.
Update the features table in README.md (Built / Planned) as features land.
