---
name: experiment-infrastructure
description: >
  Builds experiment infrastructure tailored to a project: sweep scripts,
  self-contained timestamped results with provenance, raw-first parsing,
  validity tracking, resuming interrupted runs, safe reuse of earlier
  measurements, and plotting conventions. Use when setting up or extending
  benchmarks or experiments, running sweeps, or plotting results. Triggers:
  /experiment-infrastructure, "run the experiments", "sweep", "benchmark",
  "collect perf data", "plot the results".
---

# experiment-infrastructure

This skill has no framework or template to copy. Every project runs different things, measures different things and produces different outputs, so write its infrastructure for that project. What follows are the requirements that infrastructure must meet and the guidelines for meeting them. How to implement them is up to you.

## 1. Check for existing infrastructure

Look for experiment or benchmark scripts, result directories, and run docs (`scripts/`, `experiments/`, `bench/`, `benchmarks/`, Makefile/justfile targets).

- **Clear existing setup:** use and extend it. Apply these requirements only to what you add, unless the user asks for more.
- **None:** design new infrastructure (step 2).
- **Ambiguous** (partial scripts, a different results convention): describe what you found, agree with the user on keep/extend/replace, then proceed.

## 2. Understand the project before writing code

Settle these from the code, the docs, or the user:

- **What runs:** binaries, services, scripts, models, or multi-node setups, and how each is built, found and launched.
- **One point:** what a single measurement is, what it produces (stdout, logs, files, counters, traces), and how long and costly it is.
- **Metrics:** what to measure and from where (the program itself, external tools such as `perf` or `nvidia-smi`, or derived values), with units.
- **Dimensions:** which parameters get swept, and each one's supported values.
- **Result-affecting state:** everything outside the swept parameters that can change results (hardware, system config, library/driver versions, fixed flags, seeds, input data, env vars).
- **Noise:** warmup, variance between runs, and interference from other load.

Make the infrastructure fit these answers. Keep it as small as the project allows.

## 3. Requirements

These apply to every implementation.

- **One results directory per invocation.** Default: `results/YYYY-MM-DD-HHMM-<tag>/`, with `results/` gitignored. Follow the project's own naming if it has one.
- **Self-contained.** Each results directory holds everything needed to understand and re-analyze it:
  1. **Provenance:** the exact command line and parameter grid, git commit plus dirty state, identity (hash) of what was run, tool/library versions, and the result-affecting state from step 2.
  2. **Metric list:** each metric's name, unit and source, derived metrics included.
  3. **Raw outputs:** everything each point produced, plus the exact command that ran it.
  4. **Parsed data:** one row per point (CSV/JSON), plus an aggregate over repetitions when there are any.
  5. **Plots** (section 5).
- **Raw first.** Save raw output before parsing. Parse only from saved raw output, so parsing and plotting can be rerun from the results directory without collecting data again.
- **Validity.** Mark a point invalid on failure, timeout, or unusable output, and record why. Keep invalid points in the data and report them. Never drop them silently.
- **Reuse only when it's provably equivalent.** Earlier data may stand in for a new run only if the earlier point was valid and everything that affects results matches: machine and config, code/artifact identity, non-swept settings, and parameters. If you're unsure whether something affects results, treat it as if it does.
  - Collect everything not covered fresh. For example, after a valid `--threads 1` run, `--threads all` reuses that point and runs only the other values.
  - A richer earlier collection can stand in for a lighter request.
  - Copy reused data into the new directory and record where it came from.
  - Leave the commit ID out of the check when an artifact hash already captures the code.
- **Resumable.** An interrupted or killed run can be continued in its own results directory, using only what that directory holds.
  - **Classify every planned point:**
    - **complete:** it finished and its result was recorded. This includes invalid points.
    - **partial:** it started but never finished.
    - **remaining:** it never started.
  - **Completion marker:** each point needs one, written last and atomically (write to a temp file, then rename) once its raw output and status are saved. A point with output but no marker is partial, whatever else it contains. Don't infer completion from output that merely looks complete.
  - **Planned grid:** write it to provenance before the first point runs. Resume then knows what remains without the original command line.
  - **Before continuing:** check that the result-affecting state still matches the directory's provenance. If it doesn't, stop and tell the user rather than mixing incompatible data. Show the complete/partial/remaining counts before running anything.
  - **Partial points:** delete their leftover output, or move it aside, before re-running them, so stale files never get parsed.
  - **Complete points:** keep them as they are. Re-run invalid ones only when asked (e.g. `--retry-invalid`).
  - **Recording:** append each resume (time, command) to provenance. Once a run finishes, a resumed directory must look the same as one from a single uninterrupted run.
  - **Not reuse:** resume continues one directory. Reuse copies points from other directories.
- **Honest statistics.** When there are repetitions, report the spread (std or CI), not just the mean.

## 4. Guidelines for scripts

- **Language:** Python, unless the project already runs experiments another way (shell, its own harness). Add dependencies the way the project already manages them (with `use-nix`, that means the flake).
- **Parameters:** one flag per swept dimension. Each flag accepts a single value, a comma list, or `all` (e.g. `--threads 1,2,8`, `--threads all`). Reject unsupported values.
- **Controls:**
  - `--force`: disables reuse.
  - `--resume <results-dir>`: continues an interrupted run. Whether it also takes grid flags is up to the project. If it does, reject any that differ from the recorded grid.
  - `--dry-run`: shows which points would be reused, resumed or run.
  - `--reps`: repetitions per point.
  - `--tag`: labels the results directory.
  - Collection levels (e.g. `minimal`/`full`) where auxiliary tooling is expensive.
- **Locating what runs:** search the project's build outputs, and allow an override. Don't hardcode absolute paths.
- **Normalization:** when a whole-run measurement and a work count both exist, derive per-unit metrics, e.g. `cycles/request`, `time/token`, `energy/op`.
- **Measurement hygiene:** handle warmup explicitly. Don't run overlapping experiments on the same resources. Record any noise sources you can't control.
- **Separate stages:** keep run, parse and plot as separately rerunnable steps. They can live in one script or several.

## 5. Plots

- **Form:** 2D plots with a swept parameter on the x-axis and a metric on the y-axis. Put other swept parameters in the series, or give each value its own figure. Split ranges across figures when one figure can't show them clearly. Keep one y-scale per figure.
- **Output:** write to `<results-dir>/plots/<plot-name>/`: `<plot-name>.png` and `<plot-name>.pdf`, plus the data the plot was drawn from (`data.csv`) when that is easy.
- **Labels:**
  - Use readable names, not flag or column names.
  - Put units on both axes (`Packet size (bytes)`, `Throughput (Mpps)`).
  - State the fixed parameters and the machine in the title or a caption.
- **Variant colors:**
  - Give each variant family its own hue, and each variant in a family a lighter or darker shade of that hue. A variant without a family counts as a family of its own.
  - Assign family hues in this order: `#2a78d6` blue, `#eb6834` orange, `#1baf7a` aqua, `#eda100` yellow, `#e87ba4` magenta, `#008300` green, `#4a3aa7` violet, `#e34948` red.
  - If there are more than 8 families, split them across figures instead of repeating hues.
  - Within a family, also vary the marker and line style, so variants never differ by color alone.
  - When the series is a numeric parameter, use one hue from light to dark instead.
  - A variant keeps its color in every figure.
- **Log axes:** use a log scale when positive values span a wide range. Guide: x spanning at least 8x, or y spanning at least 100x. Use base 2 for power-of-two sweeps. Label ticks with plain numbers (`64`, not `2^6`).
- **Ticks:** space x-ticks regularly: at every value for evenly spaced or power-of-two sweeps, otherwise at round steps. Categorical x-values get markers only, with no connecting lines.
- **Legend:** place it outside the axes, to the right, without a frame. Give it a title naming the series parameter. List entries in the declared variant order, grouped by family. Make sure the legend isn't cropped (`bbox_inches="tight"`).
- **Style:**
  - Draw grid lines and tick marks light (grid about `0.88` gray, thin). Remove the top and right spines.
  - Show error bars when there are repetitions.
- **Font:** IBM Plex Sans (nixpkgs `ibm-plex`), falling back to DejaVu Sans. Use a 10 pt base size, and embed fonts in PDFs (`pdf.fonttype: 42`).

## 6. Running

- Before a long sweep, show the user which points will be reused and which will be run.
- If a run is interrupted, offer to resume it rather than starting a new directory.
- Afterwards, report:
  - the results directory
  - reused vs. fresh vs. invalid counts, with the reasons for invalid points
  - the key numbers
