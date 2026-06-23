---
title: Nushell evaluation for log-parsing & data drills
tags: [nushell, shell, tooling, evaluation]
created: 2026-06-22
status: reference
---

# Nushell for your log-parsing drills

Verdict up front: **adopt nushell as a data scratchpad, not as your login
shell.** It turns the exact drills you've been doing — log parsing, CSV joins,
p95 latency, dedup — from awk/sort/uniq incantations into typed, SQL-like
pipelines. But it's deliberately *not* POSIX, and the place that bites is
sourcing cross-compile toolchain env files, which you do constantly. Keep zsh
as the default; reach for `nu` when the task is "wrangle this data."

Nushell is written in Rust and treats command output as **structured tables**
rather than text streams — closer to a mix of SQL and pandas than to bash.

---

## Your drills, side by side

### 1. Log parsing → typed columns

`parse` pulls fields out of each line with a template or `--regex`, giving you
a real table you can filter and do math on. No positional `$7` awk bookkeeping.

```nu
# App log: "2026-06-22T10:01:02Z INFO  142ms GET /v1/status 200"
open app.log
| lines
| parse --regex '(?<ts>\S+)\s+(?<level>\w+)\s+(?<latency>\d+)ms\s+(?<method>\w+)\s+(?<path>\S+)\s+(?<code>\d+)'
| update latency { into int }
| update code    { into int }
| where level == "ERROR" and latency > 500
```

Compare the awk version you'd otherwise write — this stays readable because
`latency` is an int you can compare, not a string you have to coerce per use.

### 2. CSV joins

This is where nushell flatly beats awk. `open` auto-detects CSV and gives you a
table; `join` is a real inner join on a key (also `--left`, `--right`, `--outer`).

```nu
# Join request log to a device inventory on device_id
open requests.csv
| join (open devices.csv) device_id
| select ts device_id model firmware latency_ms
| sort-by latency_ms --reverse
```

The awk/`sort … | join` two-file dance — pre-sorting both inputs, matching field
numbers — collapses to one line, and it doesn't care about column order.

### 3. p95 latency

Caveat worth knowing: nushell's `math` subcommands are avg, median, stddev,
min, max, sum, mode, variance… **but there is no built-in percentile.** Compute
it nearest-rank. Define it once as a custom command and it reads cleanly:

```nu
# Nearest-rank percentile over the piped-in list of numbers.
def "math p" [pct: float] {
  let s = ($in | sort)
  let idx = ((($s | length) - 1) * $pct | math round | into int)
  $s | get $idx
}

open metrics.csv | get latency_ms | math p 0.95
```

Per-endpoint p95 in one pipeline — the kind of thing that's genuinely annoying
in pure bash:

```nu
open metrics.csv
| group-by path
| transpose path rows
| each {|r| {
    path: $r.path
    n:   ($r.rows | length)
    p50: ($r.rows.latency_ms | math p 0.50)
    p95: ($r.rows.latency_ms | math p 0.95)
    max: ($r.rows.latency_ms | math max)
  }}
| sort-by p95 --reverse
```

### 4. Deduplication

`uniq-by` dedupes on a column; `uniq --count` gives frequencies. No
`sort | uniq -c | sort -rn` pipeline.

```nu
open events.csv | uniq-by request_id                 # drop dup request IDs
open events.csv | uniq-by request_id --count          # with occurrence counts
open access.log | lines | uniq --count | sort-by count --reverse | first 10
```

### 5. Retry wrappers

This one is a **wash, and arguably a step back.** Retry/backoff is process
orchestration, not data manipulation — bash's `until cmd; do sleep …; done` is
more natural, and you'll be running those wrappers against fleet tooling that
lives in bash anyway. Keep these in bash.

---

## The caveats that actually matter for your work

- **Not POSIX — can't source toolchain env files.** A cross-compile SDK that
  ships an `environment-setup-*` script (ARM/Yocto SDKs, ESP-IDF's `export.sh`,
  Android NDK setups) won't `source` in nu. You'd drop into bash/zsh to set up
  the cross-compile environment, which is most of your embedded day. This alone
  rules nu out as the *default login shell* for you.
- **Different operators/redirection.** `&&`/`||` and `>` don't mean what they do
  in bash; redirection is `out>` / `err>` / `o>`. Muscle memory will misfire.
- **Your bash scripts don't run in nu.** It can *call* them (they're external
  commands), but it doesn't interpret POSIX syntax. The hundreds of one-liners
  and scripts you already have stay bash.
- **`nu` script files run as external (text) commands** unless you `use` them as
  modules — minor, but surprising the first time.

## What it costs to add it alongside zsh

Almost nothing. Starship and atuin are cross-shell, so your prompt and history
search work identically in nu. Two low-friction ways to use it:

```nu
# As a subshell when you want data mode, then `exit` back to zsh:
nu

# Or one-shot, piping existing text straight in:
open big.log | nu -c 'lines | parse "{ts} {level} {msg}" | where level == "WARN"'
```

For heavier crunching nu has a built-in in-memory SQLite (`stor`) and an
optional **Polars** dataframe plugin — overkill for log triage, but there if a
"drill" ever turns into real analysis.

## Recommendation

| Use case | Shell |
|---|---|
| Default login / interactive / cross-compile / scripting | **zsh** (POSIX, sources toolchains) |
| Ad-hoc log parsing, CSV joins, percentile/dedup drills | **nu** (subshell or `nu -c`) |
| Anything you'll commit and run on a fleet device | **bash** |

Try it for two weeks on the data drills specifically. If the `parse | join |
math p` flow sticks, you'll reach for it reflexively for one-off analysis while
keeping zsh for everything that touches a toolchain.
