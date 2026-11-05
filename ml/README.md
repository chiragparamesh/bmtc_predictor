# ML workflow (Google Colab → app)

Training never happens on the laptop. Colab runs it; the repo stores only the exported model and the bundled timetable subset.

## Files

```
ml/
  train_delay_model.py              training + export (numpy only)
  tools/build_network.py            GTFS → assets/data/network.json subset
  notebooks/01_train_delay_model.ipynb   Colab wrapper (clone, train, download)
assets/data/network.json            12-route GTFS subset (ODbL), input for training
assets/models/delay_model.json      exported model the app loads
```

## Why JSON weights instead of .tflite

The model is an 11 → 24 → 24 → 2 MLP (about 900 numbers). The app evaluates it in plain Dart (`lib/features/prediction/domain/delay_model.dart`):

- it runs in the Chrome preview (TFLite has no Flutter web support) and on Android,
- no native plugin, so the APK stays small and the build stays simple,
- `test/unit/prediction_test.dart` checks Dart outputs against Python outputs saved in the JSON (`checks`).

The project rule "only exported model files live in the repo" still holds: no data, checkpoints or notebooks outputs are committed. When the graph neural network arrives (too big for hand-written inference), it will be exported to `.tflite` and run behind the same `DelayPredictor` interface, with the MLP as the web fallback.

## Train in Colab

1. Open `ml/notebooks/01_train_delay_model.ipynb` on GitHub → **Open in Colab** (or upload it). CPU runtime is fine.
2. Run **Option A** for v0 (traffic prior), or **Option B** after pasting your reports CSV.
3. The last cell prints the metrics and downloads `delay_model.json`.
4. Copy it into `D:\Projects\bmtc_predictor\assets\models\`, then commit and push. `flutter test` must pass (parity checks), and Actions builds the APK.

## Labels: the traffic prior (v0)

There is no public dataset of actual BMTC arrival times; GTFS has the schedule only (already slower at peak). v0 learns a documented prior, defined in `prior_mean_delay()`:

| Factor | Assumption |
|---|---|
| Time of day | Weekday peaks around 09:30 and 18:45 (evening worse); weekends milder |
| Corridor | ORR +50%, Silk Board +40%, Majestic +25%, airport +15% |
| Progress | Delay builds along the trip: 30% at the first stop, 100% at the last |
| Rain | +7% per mm/h (max +80%), worse at peak |
| AC Vajra | 10% better |
| Spread | Log-normal noise (σ = 0.45), shifted 1 minute early |

It's a stand-in, labelled "early estimate" in the app. Every real report beats it.

## Ground truth: rider reports

In the app: at a stop, tap **Arrived** when your bus comes. Each report stores the model inputs, the prediction and the actual delay.

- **On the phone, immediately:** per-route correction `mean(actual − predicted) × n / (n + 3)`.
- **In Colab:** **Your reports → Copy reports as CSV**, paste into the notebook, and run with `--reports`. Reports are weighted 20× against prior samples.

## Roadmap

1. Collect reports (aim for 100+ across peak and off-peak, dry and rain).
2. Live rain: Open-Meteo hourly precipitation instead of the toggle.
3. XGBoost baseline on reports (distilled into the MLP for on-device use).
4. GNN over the stop graph (`network.json` stop sequences = edges) so delay at one stop informs the next.
