"""Compare experimental controller to measured V0.0 results."""
import csv
import json
import math
import os
from pathlib import Path

reference=json.loads(Path("experiments/v01/reference.json").read_text())
key=lambda x:(x["strategy"],x["wind"],x["road"])
refs={key(x):x for x in reference["cases"]}
cases={}
errors=[]
for p in sorted(Path("case-artifacts").rglob("metrics.json")):
    x=json.loads(p.read_text())
    k=key(x)
    if k not in refs or k in cases:
        errors.append(f"Unexpected or duplicate case: {k}")
        continue
    cases[k]=x
    if x["upstream_sha"]!=reference["upstream_sha"] or x["release"]!="2022b":
        errors.append(f"Wrong upstream/release: {k}")
    if not all(x[n] for n in ("reached_simulation_end","lateral_limit_pass","distance_gate_pass")):
        errors.append(f"Validity gate failed: {k}")
    if not math.isclose(x["Phi"],sum(x[f"Phi{i}"]*w for i,w in enumerate((1,60,3,10),1)),rel_tol=1e-8,abs_tol=1e-8):
        errors.append(f"Score mismatch: {k}")
if refs.keys()-cases.keys():
    errors.append(f"Missing cases: {sorted(refs.keys()-cases.keys())}")
out=Path("experiment-summary");out.mkdir(exist_ok=True)
lines=["# V0.1 Public reference TCS — public cycle","",
       "| Parent | Wind | Road | Original | TCS | Reduction % | Original slip | TCS slip | Final x | RMSE | Valid |",
       "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|"]
rows=[]
for k,x in sorted(cases.items()):
    r=refs[k];s,w,d=k
    valid=all(x[n] for n in ("reached_simulation_end","lateral_limit_pass","distance_gate_pass"))
    pct=100*(1-x["Phi"]/r["Phi"])
    lines.append(f"| {('Baseline','Improved')[s-1]} | {w} | {d} | {r['Phi']:.3f} | {x['Phi']:.3f} | {pct:.2f} | {r['Phi2']:.4f} | {x['Phi2']:.4f} | {x['final_x_m']:.2f} | {x['speed_rmse_mps']:.3f} | {valid} |")
    rows.append({**x,"original_Phi":r["Phi"],"original_Phi2":r["Phi2"],"reduction_pct":pct})
totals={}
for s in (1,2):
    ks=[k for k in refs if k[0]==s]
    if all(k in cases for k in ks):
        before=sum(refs[k]["Phi"] for k in ks)
        after=sum(cases[k]["Phi"] for k in ks)
        valid=all(all(cases[k][n] for n in ("reached_simulation_end","lateral_limit_pass","distance_gate_pass")) for k in ks)
        totals[s]={"original":before,"candidate":after,"reduction_pct":100*(1-after/before),"internal_gate_pass":valid}
        lines.append(f"\n**{('Baseline','Improved')[s-1]} + TCS:** {after:.6f} vs {before:.6f} ({totals[s]['reduction_pct']:.2f}% reduction); internal gate: {valid}.")
lines += ["","Public reference controller only. Distance gate is an internal engineering check, not an official completion criterion. No secret-cycle results.",""]
if errors: lines += ["## Errors",*["- "+e for e in errors]]
summary="\n".join(lines)+"\n"
(out/"summary.md").write_text(summary)
(out/"summary.json").write_text(json.dumps({"cases":rows,"totals":totals,"errors":errors},indent=2))
if rows:
    with (out/"scores.csv").open("w",newline="") as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
print(summary)
if os.getenv("GITHUB_STEP_SUMMARY"):
    with open(os.environ["GITHUB_STEP_SUMMARY"],"a") as f:f.write(summary)
if errors:raise SystemExit(1)
