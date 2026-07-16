# architecture-lint

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
language and module layout.

## Why I built this

I'm a solo founder building a large production iOS app (Swift 6, strict
concurrency, six-package architecture). There's no team to catch an
accidental layering violation in review, so the CI gate has to. This is the
generalized, sanitized version of a script that runs on every commit in that
codebase.

More on the production side of that stack (cost control, caching, circuit
breakers for LLM calls): [What Running an LLM in Production Actually Costs You](https://dev.to/orens/what-running-an-llm-in-production-actually-costs-you-20ih).
