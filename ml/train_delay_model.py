"""Train the BMTC delay model and export it for the app.

Runs in Google Colab (or any Python 3 with numpy). Output: assets/models/delay_model.json,
a tiny MLP (11 -> 24 -> 24 -> 2) that the app evaluates in plain Dart (web + Android).

    python ml/train_delay_model.py                       # v0: traffic prior only
    python ml/train_delay_model.py --reports reports.csv # + your "bus arrived" reports

Outputs per stop: q50 (median delay, minutes) and q90 (90% of buses arrive within this delay).

WHY A PRIOR: there is no public dataset of actual BMTC arrival times. GTFS gives the schedule only
(already slower at peak). v0 therefore learns a documented traffic prior (below). Real ground truth
comes from the app's "Bus arrived" reports, exported as CSV and mixed in with --reports (weighted up).
The prior is a stand-in, and the app labels v0 predictions as early estimates.
"""
import argparse
import csv
import json
import math
import os
import sys
from datetime import datetime, timezone

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NETWORK = os.path.join(ROOT, "assets", "data", "network.json")
OUT = os.path.join(ROOT, "assets", "models", "delay_model.json")

# The feature contract shared with lib/features/prediction/domain/delay_features.dart.
FEATURES = [
    "hour_sin", "hour_cos", "is_weekend", "trip_progress", "sched_min_from_start_div120",
    "corridor_orr", "corridor_silk_board", "corridor_majestic", "corridor_airport",
    "is_vajra", "rain_mmh_div10",
]
QUANTILES = [0.5, 0.9]


def features(hour, weekend, progress, sched_min, corridors, vajra, rain_mmh):
    return [
        math.sin(2 * math.pi * hour / 24), math.cos(2 * math.pi * hour / 24), float(weekend),
        progress, sched_min / 120.0,
        float("orr" in corridors), float("silk_board" in corridors),
        float("majestic" in corridors), float("airport" in corridors),
        float(vajra), min(rain_mmh, 30.0) / 10.0,
    ]


# ---------------------------------------------------------------- traffic prior (v0 labels)
def prior_mean_delay(hour, weekend, progress, corridors, vajra, rain):
    """Mean delay in minutes beyond the GTFS schedule. Assumptions (documented, tunable):
    - weekday peaks around 09:30 and 18:45, evening worse; weekends milder, midday + evening
    - corridor multipliers: ORR +50%, Silk Board +40%, Majestic/CBD +25%, airport +15%
    - delay builds up along the trip (30% at the first stop, 100% at the last)
    - rain: +7% per mm/h (max +80%), worse when it rains at peak; AC Vajra buses 10% better
    """
    if weekend:
        peak = 0.45 * math.exp(-((hour - 13) / 3.0) ** 2) + 0.6 * math.exp(-((hour - 19) / 2.0) ** 2)
    else:
        peak = math.exp(-((hour - 9.5) / 1.5) ** 2) + 1.15 * math.exp(-((hour - 18.75) / 1.75) ** 2)
    corr = 1 + 0.5 * ("orr" in corridors) + 0.4 * ("silk_board" in corridors) \
        + 0.25 * ("majestic" in corridors) + 0.15 * ("airport" in corridors)
    base = (1.5 + 11 * peak) * corr
    rainf = min(1 + min(0.07 * rain, 0.8) + 0.05 * rain * peak, 2.2)
    return base * (0.3 + 0.7 * progress) * rainf * (0.9 if vajra else 1.0)


def sample_prior(network, n, rng):
    routes = {r["id"]: r for r in network["routes"]}
    pats = network["patterns"]
    X, y = [], []
    for _ in range(n):
        p = pats[rng.integers(len(pats))]
        r = routes[p["route"]]
        start, prof = p["trips"][rng.integers(len(p["trips"]))]
        i = int(rng.integers(len(p["stops"])))
        off = p["profiles"][prof][i]
        hour = ((start + off) / 3600.0) % 24
        weekend = rng.random() < 2 / 7
        progress = i / max(1, len(p["stops"]) - 1)
        rain = 0.0 if rng.random() < 0.7 else float(rng.exponential(6.0))
        mean = prior_mean_delay(hour, weekend, progress, r["corridors"], r["vajra"], rain)
        delay = mean * rng.lognormal(0.0, 0.45) - 1.0
        X.append(features(hour, weekend, progress, off / 60.0, r["corridors"], r["vajra"], rain))
        y.append(min(max(delay, -4.0), 90.0))
    return np.array(X, dtype=np.float64), np.array(y, dtype=np.float64)


def load_reports(path):
    """CSV exported by the app ("Export reports"): f0..f10 feature columns + delay_min."""
    X, y = [], []
    with open(path, newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            X.append([float(row[f"f{i}"]) for i in range(len(FEATURES))])
            y.append(float(row["delay_min"]))
    return np.array(X), np.array(y)


# ---------------------------------------------------------------- tiny MLP in numpy
def softplus(x):
    return np.log1p(np.exp(-np.abs(x))) + np.maximum(x, 0)


def sigmoid(x):
    return 1 / (1 + np.exp(-x))


def init(sizes, rng):
    return [(rng.normal(0, math.sqrt(2 / a), (a, b)), np.zeros(b)) for a, b in zip(sizes[:-1], sizes[1:])]


def forward(params, X):
    acts = [X]
    h = X
    for k, (W, b) in enumerate(params):
        z = h @ W + b
        h = np.maximum(z, 0) if k < len(params) - 1 else z
        acts.append(h)
    raw = acts[-1]
    q50 = raw[:, 0]
    q90 = q50 + softplus(raw[:, 1])
    return np.stack([q50, q90], 1), acts


def pinball_grad(pred, y, w):
    """d(weighted pinball loss)/d(pred) for both quantiles."""
    g = np.zeros_like(pred)
    for j, q in enumerate(QUANTILES):
        e = y - pred[:, j]
        g[:, j] = np.where(e > 0, -q, 1 - q) * w
    return g / w.sum()


def pinball(pred, y, q):
    e = y - pred
    return float(np.mean(np.maximum(q * e, (q - 1) * e)))


def train(X, y, w, epochs=12, lr=3e-3, batch=512, seed=0):
    rng = np.random.default_rng(seed)
    params = init([X.shape[1], 24, 24, 2], rng)
    m = [(np.zeros_like(W), np.zeros_like(b)) for W, b in params]
    v = [(np.zeros_like(W), np.zeros_like(b)) for W, b in params]
    t = 0
    for ep in range(epochs):
        idx = rng.permutation(len(X))
        for s in range(0, len(X), batch):
            bi = idx[s:s + batch]
            pred, acts = forward(params, X[bi])
            g = pinball_grad(pred, y[bi], w[bi])
            raw = acts[-1]
            # back through the output head: q50 = r0, q90 = r0 + softplus(r1)
            graw = np.stack([g[:, 0] + g[:, 1], g[:, 1] * sigmoid(raw[:, 1])], 1)
            grads = []
            delta = graw
            for k in range(len(params) - 1, -1, -1):
                W, _ = params[k]
                grads.append((acts[k].T @ delta, delta.sum(0)))
                if k > 0:
                    delta = (delta @ W.T) * (acts[k] > 0)
            grads.reverse()
            t += 1
            for k, ((W, b), (gW, gb)) in enumerate(zip(params, grads)):
                mW, mb = m[k]
                vW, vb = v[k]
                mW = 0.9 * mW + 0.1 * gW; mb = 0.9 * mb + 0.1 * gb
                vW = 0.999 * vW + 0.001 * gW ** 2; vb = 0.999 * vb + 0.001 * gb ** 2
                m[k], v[k] = (mW, mb), (vW, vb)
                c1, c2 = 1 - 0.9 ** t, 1 - 0.999 ** t
                params[k] = (W - lr * (mW / c1) / (np.sqrt(vW / c2) + 1e-8),
                             b - lr * (mb / c1) / (np.sqrt(vb / c2) + 1e-8))
        if ep == epochs // 2:
            lr *= 0.3
    return params


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reports", help="CSV exported from the app's Reports screen")
    ap.add_argument("--report-weight", type=float, default=20.0)
    ap.add_argument("--samples", type=int, default=200_000)
    args = ap.parse_args()

    network = json.load(open(NETWORK, encoding="utf-8"))
    rng = np.random.default_rng(42)
    X, y = sample_prior(network, args.samples, rng)
    w = np.ones(len(y))
    n_reports = 0
    if args.reports:
        Xr, yr = load_reports(args.reports)
        n_reports = len(yr)
        X, y = np.vstack([X, Xr]), np.concatenate([y, yr])
        w = np.concatenate([w, np.full(len(yr), args.report_weight)])
        print(f"mixed in {n_reports} real reports (weight {args.report_weight})")

    split = int(0.85 * len(y))
    perm = rng.permutation(len(y))
    tr, te = perm[:split], perm[split:]
    params = train(X[tr], y[tr], w[tr])
    pred, _ = forward(params, X[te])

    # Baselines: "bus is on schedule" (0 delay) and "average delay for this hour".
    hours = (np.degrees(np.arctan2(X[:, 0], X[:, 1])) / 15) % 24
    hb = np.floor(hours).astype(int)
    hour_mean = {h: float(np.median(y[tr][hb[tr] == h])) for h in range(24) if np.any(hb[tr] == h)}
    base_hour = np.array([hour_mean.get(h, 0.0) for h in hb[te]])
    metrics = {
        "test_samples": int(len(te)),
        "mae_q50_min": round(float(np.mean(np.abs(pred[:, 0] - y[te]))), 3),
        "mae_schedule_baseline_min": round(float(np.mean(np.abs(y[te]))), 3),
        "mae_hour_median_baseline_min": round(float(np.mean(np.abs(base_hour - y[te]))), 3),
        "pinball_q50": round(pinball(pred[:, 0], y[te], 0.5), 4),
        "pinball_q90": round(pinball(pred[:, 1], y[te], 0.9), 4),
        "q90_coverage": round(float(np.mean(y[te] <= pred[:, 1])), 4),
        "real_reports_used": n_reports,
    }
    print(json.dumps(metrics, indent=2))

    # Export precision: round weights first, so the parity checks use exactly what ships.
    params = [(W.round(6), b.round(6)) for W, b in params]
    # Parity checks: the Dart test re-evaluates these inputs and must get the same outputs.
    check_idx = rng.choice(len(te), 8, replace=False)
    cx = X[te][check_idx].round(6)
    cy, _ = forward(params, cx)
    model = {
        "name": "bmtc-delay-mlp",
        "version": datetime.now(timezone.utc).strftime("%Y.%m.%d") + ("-reports" if n_reports else "-prior"),
        "trainedOn": "traffic prior" + (f" + {n_reports} rider reports" if n_reports else " (no real arrivals yet)"),
        "feedVersion": network.get("feedVersion"),
        "features": FEATURES,
        "quantiles": QUANTILES,
        "head": "q50 = out0; q90 = out0 + softplus(out1)",
        "layers": [{"w": W.tolist(), "b": b.tolist(),
                    "activation": "relu" if k < len(params) - 1 else "linear"}
                   for k, (W, b) in enumerate(params)],
        "metrics": metrics,
        "checks": [{"x": [float(v) for v in xi], "y": [float(a) for a in yi]} for xi, yi in zip(cx, cy)],
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    json.dump(model, open(OUT, "w"), separators=(",", ":"))
    print(f"wrote {OUT} ({os.path.getsize(OUT) // 1024} KB)")


if __name__ == "__main__":
    sys.exit(main())
