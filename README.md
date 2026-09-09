# architecture-lint

[![CI](https://github.com/OrenSegal/architecture-lint/actions/workflows/ci.yml/badge.svg)](https://github.com/OrenSegal/architecture-lint/actions/workflows/ci.yml)

A config-driven module-boundary linter with a ratchet baseline, extracted from
patterns I use to keep a large production Swift codebase honest about its own
architecture docs.

## The problem

Architecture diagrams and "layer X must not import layer Y" rules rot the
moment nobody's forced to check them. Six months in, the diagram says one
thing and the imports say another, and nobody notices until a refactor gets
tangled in a dependency cycle that was never supposed to exist.

## The approach

Two ideas, both boringly simple and both worth stealing independent of each
other:

1. **Config-driven boundary rules.** Your module graph (`Domain → Data/Services
   → UI → App`, or whatever shape fits your codebase) is a list of
   `module|forbidden_import` pairs, not hardcoded logic. Point it at Swift
   packages, TypeScript workspaces, Python packages, Go modules, anything
   with directories and a grep-able import statement.

2. **Ratchet baseline, not a hard gate.** Introducing a lint rule into a
   codebase that already has debt usually means either a giant one-time
   cleanup PR, or nobody ever turns the rule on. Instead: record the current
   violation count as a baseline, and only fail CI on *new* violations above
   that number. The baseline can shrink (encouraged, celebrated even) but
   never grow. This is the difference between a rule that ships and one that
   stays a wiki page forever.

Inline exemptions (`// arch-exempt: <rule>`) handle the legitimate exceptions
(a framework that requires a singleton, e.g.) without hiding them in a config
file nobody reads six months later.

## Usage

```bash
./architecture-lint.sh --init-baseline   # snapshot current violations
./architecture-lint.sh                   # check, fail only on regressions
```

Edit the `BOUNDARIES` array and the `MODULES_ROOT` / `FILE_GLOB` /
`IMPORT_KEYWORD` variables at the top of the script for your codebase's
language and module layout. All three are overridable via `ARCH_LINT_*`
environment variables — `tests/run.sh` uses this to exercise the same script
against fixtures in three different languages without editing the file.

## Real output

Run against `tests/fixtures/violation`, where `Domain/User.ts` imports from
`UI/`, a boundary the config forbids, with an empty (all-zero) baseline:

```
Architecture Lint
==================

x Domain must not import UI:
   tests/fixtures/violation/src/Domain/User.ts:1:import { renderScreen } from '../UI/Screen';

Boundary checks run: 5

Ratchet: boundaries (baseline=0, current=1)
  REGRESSION: 1 new violation(s)

Ratchet: no_singletons (baseline=0, current=0)
  OK: at or within baseline

x Architecture lint failed: 1 violation(s)
  Fix them, or add an inline exemption with justification.
```

Exit code `1`. Run it against `tests/fixtures/clean` with that same baseline
and boundary violations are now *below* baseline, which is reported as
"Improved" rather than a failure — exit `0`.

Both rules — the boundary check and `no_singletons` — are ratcheted the same
way: the baseline records a violation *count* (not just which rules were
broken), and only new violations beyond that count fail the gate. This is
why turning this on in a codebase that already has boundary violations
doesn't require fixing them all first — run `--init-baseline` once and only
new violations are gated from then on.

## Using it in your own CI

There's no package to install — copy `architecture-lint.sh` into your repo
(alongside a `.arch_lint_baseline.json` from `--init-baseline`), edit the
`BOUNDARIES` array for your module graph, commit both, and gate CI on it:

```yaml
# .github/workflows/architecture-lint.yml
name: Architecture Lint

on:
  push:
    branches: [main]
  pull_request:

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run architecture-lint
        run: ./architecture-lint.sh
```

That's the whole setup — the script and baseline file live in your repo like
any other config, so there's nothing external for CI to fetch or pin a
version of. If you're evaluating whether to adopt it, curl the script to try
it against a checkout without committing it yet:

```bash
curl -fsSL https://raw.githubusercontent.com/OrenSegal/architecture-lint/main/architecture-lint.sh -o architecture-lint.sh
chmod +x architecture-lint.sh
./architecture-lint.sh --init-baseline
```

## Tests

```bash
./tests/run.sh
```

Eleven fixture-backed cases, each asserting a real exit code against the real
script — no mocking, this is the same binary the usage example above ran:

- a clean module graph passes
- a boundary violation (`Domain` importing `UI`) fails against a zero baseline
- a singleton at baseline passes
- a new singleton beyond the baseline is caught as a regression
- an `// arch-exempt: singleton` comment excludes that line from the count
- a boundary violation count at baseline passes
- a new boundary violation beyond the baseline is caught as a regression
- fewer current violations than baseline reports "Improved" and still passes
- a missing baseline file exits 1 with a message
- an anchored import match (`import CoreData`) doesn't false-positive against
  a `Data` boundary rule
- a baseline file predating the `boundaries` key defaults it to 0 and warns,
  instead of crashing

CI runs this suite, plus ShellCheck against the shell scripts, on every push
(see the badge above).

## Why I built this

I'm a solo founder building a large production iOS app (Swift 6, strict
concurrency, six-package architecture). There's no team to catch an
accidental layering violation in review, so the CI gate has to. This is the
generalized, sanitized version of a script that runs on every commit in that
codebase.
