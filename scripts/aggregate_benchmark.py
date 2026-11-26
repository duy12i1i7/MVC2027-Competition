"""Aggregate official MVC2027 public-cycle benchmark artifacts."""
import csv
import json
import math
import os
from pathlib import Path

root = Path("benchmark-artifacts")
out = Path("benchmark-summary")
out.mkdir(exist_ok=True)
expected = {(s,w,r) for s in (1,2) for w,r in ((0,0),(1,0),(0,1),(1,1))}
rows = {}
errors = []
for path in sorted(root.rglob("metrics.json")):
    x = json.loads(path.read_text())
    key = (x["strategy"], x["wind"], x["road"])
    if key not in expected or key in rows:
        errors.append(f"Unexpected/duplicate case {key}: {path}")
        continue
    rows[key] = x
    if not x["reached_simulation_end"] or not x["lateral_limit_pass"]:
        errors.append(f"Failed simulation/lateral limit: {key}")
    if not math.isclose(x["Phi"], sum(x[k]*w for k,w in zip(("Phi1","Phi2","Phi3","Phi4"),(1,60,3,10))), rel_tol=1e-8,abs_tol=1e-8):
        errors.append(f"Score mismatch: {key}")
missing = expected - rows.keys()
if missing:
    errors.append(f"Missing cases: {sorted(missing)}")
fields = ["strategy","wind","road","Phi1","Phi2","Phi3","Phi4","Phi","elapsed_seconds","sample_count","final_time_s","expected_time_s","reached_simulation_end","lateral_limit_pass","max_abs_y_m","final_x_m","reference_distance_m","distance_error_m","final_vx_mps","speed_rmse_mps","slip_peak_FR_FL_RR_RL","slip_rms_FR_FL_RR_RL","time_outside_dwpt_lateral_s","dwpt_received_Wh","ay_rms_mps2","upstream_sha","release","matlab_version"]
with (out/"scores.csv").open("w",newline="") as f:
    writer=csv.DictWriter(f,fieldnames=fields,extrasaction="ignore")
    writer.writeheader()
    writer.writerows(rows[k] for k in sorted(rows))
lines=["# MVC2027 public-cycle benchmark","", "| Strategy | Wind | Road | Energy | Slip | DWPT | Lateral accel. | Total | Max abs y (m) | End x (m) | Speed RMSE |", "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
for (s,w,r),x in sorted(rows.items()):
    lines.append(f"| {('Baseline','Improved')[s-1]} | {w} | {r} | {x['Phi1']:.3f} | {x['Phi2']:.3f} | {x['Phi3']:.3f} | {x['Phi4']:.3f} | {x['Phi']:.3f} | {x['max_abs_y_m']:.4f} | {x['final_x_m']:.2f} | {x['speed_rmse_mps']:.3f} |")
totals={}
for s in (1,2):
    subset=[x for k,x in rows.items() if k[0]==s]
    if len(subset)==4:
        totals[s]=sum(x["Phi"] for x in subset)
        lines.append(f"\n**{('Baseline','Improved')[s-1]} public-cycle sum:** {totals[s]:.6f}")
if len(totals)==2 and totals[1]!=0:
    lines.append(f"\nImproved reduction relative to Baseline: {(1-totals[2]/totals[1])*100:.3f}%")
lines += ["","These are public-cycle scores only, not final competition scores. Simulation end and lateral limit checks do not certify journey completion; inspect final distance, speed and traces.",""]
if errors:
    lines += ["## Benchmark errors", *["- "+e for e in errors]]
summary="\n".join(lines)+"\n"
(out/"summary.md").write_text(summary)
(out/"summary.json").write_text(json.dumps({"cases":[rows[k] for k in sorted(rows)],"public_cycle_totals":totals,"errors":errors},indent=2))
print(summary)
if os.getenv("GITHUB_STEP_SUMMARY"):
    with open(os.environ["GITHUB_STEP_SUMMARY"],"a") as f: f.write(summary)
if errors: raise SystemExit(1)
