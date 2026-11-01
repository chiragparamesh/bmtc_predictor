# ML workflow (Google Colab → .tflite)

Training never happens on the laptop. Colab does the heavy work; the repo only stores the exported model, the bundled GTFS subset and small metadata.

## Folder layout

```
ml/
  README.md                this file
  notebooks/               Colab notebooks (.ipynb), committed without outputs
assets/data/gtfs_subset/   compact JSON produced by the GTFS notebook (committed)
assets/models/
  delay_model.tflite       exported model (committed)
  delay_model.json         feature order, scaling constants, version, metrics
```

Raw GTFS, weather dumps and checkpoints stay in Google Drive (git-ignored).

## Notebooks (planned)

| Notebook | Does |
|---|---|
| `01_gtfs_subset.ipynb` | Download [Vonter/bmtc-gtfs](https://github.com/Vonter/bmtc-gtfs), filter to Silk Board / ORR / Majestic routes, write `assets/data/gtfs_subset/*.json` |
| `02_weather.ipynb` | Pull Open-Meteo hourly precipitation for Bengaluru |
| `03_xgboost_baseline.ipynb` | Build the feature table, train XGBoost (median + P90), evaluate MAE and calibration |
| `04_export_tflite.ipynb` | Distill into a small Keras MLP, convert to TFLite, check parity, write metadata JSON |
| `05_gnn.ipynb` | Graph model over the stop network (PyTorch Geometric), quantile heads, export |

## Steps

1. Open the notebook in Colab (CPU is fine for XGBoost; T4 GPU for the GNN).
2. Mount Drive for raw data and checkpoints.
3. Run, check metrics against the baseline ("schedule + mean delay by hour").
4. Export `.tflite` + metadata JSON, verify that TFLite and Python predictions match on 100 rows.
5. Copy the files into `assets/models/` (and `assets/data/gtfs_subset/` if changed), commit, push. CI builds the APK.

## Rules

- The feature order in `delay_model.json` is the contract between Colab and Dart. Change both together.
- Keep notebooks output-free before committing.
- TFLite does not run on Flutter web: Chrome preview uses the heuristic predictor.
