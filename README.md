# MVC2027 — public benchmark (V0.0)

Reproducible baseline evaluation of IEEE VTS Motor Vehicle Challenge 2027 using MATLAB/Simulink R2022b on GitHub-hosted Linux. This public repository contains evaluation infrastructure only, not private competition algorithms.

Upstream: https://github.com/VTSociety/MVC_2027
Pinned source: 165d34380f522b6ef0f3a4d908c8838d1c512cc8 (2026-11-10). Original model and scoring remain unchanged; upstream attribution and CC BY-NC 4.0 license apply to upstream files.

## Run
Open Actions > MVC2027 Public Benchmark > Run workflow. Eight jobs run the two official strategies across all four combinations of wind and road variation. The workflow also runs when benchmark scripts/workflow change on main.

The harness calls the original sim_para.m, driving_condition.m, meso_para.m, model and scoring.m, using only scenario flags and strategy selection as in main.m. The official scoring script produces each score; the aggregator checks the weighted sum and adds the four conditions for each strategy.

Each case artifact contains official_score.txt, metrics.json, trace.csv (decimated), signals.mat (full-resolution selected signals), matlab.log and diagnostics.png (if graphics export succeeds). The aggregate artifact contains scores.csv, summary.json, summary.md. View the aggregate job summary for scores.

A completed simulation with max absolute lateral position <= 5 m is not by itself proof that the vehicle completed the journey. Inspect final position, reference distance, speed and traces. The secret cycle is unavailable, so these are NOT final competition scores.

No controller may access evaluation-only signals or restricted parameters. Keep private controller development separate; do not put competition secrets, license keys or personal data here.
