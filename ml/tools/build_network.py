"""Build the bundled BMTC subset (assets/data/network.json) from the Vonter GTFS feed.
Data: (c) BMTC via Namma BMTC app, compiled by Vonter (github.com/Vonter/bmtc-gtfs), ODbL 1.0."""
import csv, sys, json, collections
G, OUT = sys.argv[1], sys.argv[2]
ROUTES = {  # short name -> corridors
 '500-D':['orr','silk_board'], 'V-500D':['orr','silk_board'], '500-A':['orr','silk_board'], '500-F':['orr','silk_board'],
 '600-F':['silk_board'], 'MF-5':['silk_board'], 'KIA-8':['orr','silk_board','airport'], 'KIA-9':['majestic','airport'],
 'KBS-3A':['silk_board','majestic'], '25-A':['majestic'], '90-E':['majestic'], '300-MV':['majestic'],
}
VAJRA = lambda s: s.startswith('V-') or s.startswith('KIA-')
routes = {r['route_id']: r for r in csv.DictReader(open(f'{G}/routes.txt', encoding='utf-8')) if r['route_short_name'] in ROUTES}
trips = {r['trip_id']: r for r in csv.DictReader(open(f'{G}/trips.txt', encoding='utf-8')) if r['route_id'] in routes}
kn = {r['record_id']: r['translation'] for r in csv.DictReader(open(f'{G}/translations.txt', encoding='utf-8'))
      if r['table_name']=='stops' and r['field_name']=='stop_name' and r['language']=='kn'}
st = collections.defaultdict(list)
for r in csv.DictReader(open(f'{G}/stop_times.txt', encoding='utf-8')):
    if r['trip_id'] in trips: st[r['trip_id']].append(r)
def secs(t): h,m,s = map(int,t.split(':')); return h*3600+m*60+s

patterns = {}
for tid, rows in st.items():
    rows.sort(key=lambda r:int(r['stop_sequence']))
    t = trips[tid]; t0 = secs(rows[0]['arrival_time'])
    key = (t['route_id'], t['direction_id'], tuple(r['stop_id'] for r in rows))
    offs = tuple(secs(r['arrival_time'])-t0 for r in rows)
    p = patterns.setdefault(key, dict(headsign=t['trip_headsign'], profiles={}, trips=[]))
    pi = p['profiles'].setdefault(offs, len(p['profiles']))
    p['trips'].append([t0, pi])

used_stops = set()
out_patterns = []
for i, ((rid, d, stops), p) in enumerate(sorted(patterns.items(), key=lambda kv: (routes[kv[0][0]]['route_short_name'], kv[0][1], -len(kv[1]['trips'])))):
    if len(stops) < 3 or len(p['trips']) < 3: continue   # skip depot shuttles / one-offs
    used_stops.update(stops)
    profiles = [list(o) for o,_ in sorted(p['profiles'].items(), key=lambda kv: kv[1])]
    out_patterns.append(dict(id=f"p{i}", route=rid, dir=int(d), headsign=p['headsign'], stops=list(stops),
                             profiles=profiles, trips=sorted(p['trips'])))
stops_all = {r['stop_id']: r for r in csv.DictReader(open(f'{G}/stops.txt', encoding='utf-8'))}
out_stops = []
for sid in sorted(used_stops):
    s = stops_all[sid]
    out_stops.append(dict(id=sid, name=s['stop_name'], desc=s['stop_desc'] or s['stop_name'], kn=kn.get(sid, ''),
                          lat=float(s['stop_lat']), lon=float(s['stop_lon'])))
used_routes = {p['route'] for p in out_patterns}
out_routes = [dict(id=rid, short=routes[rid]['route_short_name'], long=routes[rid]['route_long_name'],
                   vajra=VAJRA(routes[rid]['route_short_name']), corridors=ROUTES[routes[rid]['route_short_name']])
              for rid in sorted(used_routes, key=lambda r: routes[r]['route_short_name'])]
feed = next(csv.DictReader(open(f'{G}/feed_info.txt', encoding='utf-8')))
doc = {"_source": "BMTC timetable subset. Data from the Namma BMTC app compiled by Vonter "
                  "(https://github.com/Vonter/bmtc-gtfs), licensed under ODbL 1.0. This subset is also ODbL 1.0.",
       "feedVersion": feed['feed_version'], "routes": out_routes, "stops": out_stops, "patterns": out_patterns}
json.dump(doc, open(OUT,'w',encoding='utf-8'), ensure_ascii=False, separators=(',',':'))
print(f"routes={len(out_routes)} stops={len(out_stops)} patterns={len(out_patterns)} trips={sum(len(p['trips']) for p in out_patterns)} "
      f"kn_names={sum(1 for s in out_stops if s['kn'])} max_time_h={max(t for p in out_patterns for t,_ in p['trips'])/3600:.1f} "
      f"max_offset_min={max(o for p in out_patterns for pr in p['profiles'] for o in pr)/60:.0f}")
