# AGENTS.md

Guidance for AI agents — and humans — working in this repository.

`CLAUDE.md` is a symlink to this file. There is only one copy to keep current.

## This repository is public. Read this section before writing anything.

Everything committed here is world-readable and effectively permanent: GitHub
retains forks, mirrors and pull-request history, so rewriting a commit does not
remove the content from the internet. A leak here cannot be undone, only rotated
around.

**Never commit:**

- **Credentials of any kind.** API keys, `.p8` / `.pem` / `.p12` / `.key` files,
  tokens, passwords, or signing certificates. `scripts/release.sh` reads all of
  them from environment variables precisely so none has to live in the tree —
  keep it that way when extending it.
- **Absolute paths from a developer's machine** (`/Users/<name>/…`).
- **Session logs, chat transcripts, or agent scratch files.** This is the single
  most common way a key reaches a public repo: the file looks like harmless
  notes, so nobody reads it line by line before committing it.
- **Anything about the commercial edition beyond what the README already states
  publicly.** No pricing strategy, no licence-check or paywall code, no revenue,
  cost or competitor analysis, no internal design documents. Bytetally is
  developed in a separate private repository; code and docs do not flow from
  there to here.

What *is* fine and deliberate: the Team ID and the `Developer ID Application`
name in `scripts/release.sh`. Both are already visible to anyone who runs
`codesign -dv` on a published build, and the script accepts overrides via
`SIGN_IDENTITY` / `TEAM_ID`.

Before any commit or PR, re-read the list above against your diff. If something
is borderline, leave it out and ask — it is far cheaper than a rotation.

## What this project is

iTraffic is a small, open-source macOS menu-bar monitor showing per-process
network rates. It drives `/usr/bin/nettop` directly and has no third-party
dependencies, no network requests of its own, and no sandbox.

There is also Bytetally, a separately developed commercial edition from the same
developer, described in the README. It lives in its own private repository.

## Layout

```
ITrafficMonitorForMac/       app sources
  Service/NettopRunner.swift   drives /usr/bin/nettop
  Network.swift                parses frames, feeds the models
  Model/                       ObservableObjects backing the two surfaces
  ContentView.swift            popover: header + process list
  StatusBarView.swift          menu-bar rates
project.yml                  XcodeGen source of truth; the .xcodeproj is generated
scripts/release.sh           the whole release, one command
changelog/<version>.md       release notes, consumed by release.sh
```

`ITrafficMonitorForMac.xcodeproj` is generated from `project.yml`. Edit the YAML,
run `xcodegen generate`, and commit both.

## Build

```bash
brew install xcodegen
xcodegen generate
xcodebuild build -project ITrafficMonitorForMac.xcodeproj \
  -scheme ITrafficMonitorForMac -configuration Release
```

`CODE_SIGN_IDENTITY` is ad-hoc (`-`) in `project.yml` so a fresh clone builds
with no certificate at all. Release builds override it (see below).

## Release

Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`, write
`changelog/<version>.md`, commit, then:

```bash
scripts/release.sh --dry-run   # build, notarise, verify — publishes nothing
scripts/release.sh             # the real thing
```

It archives with the Developer ID certificate, notarises, staples, re-zips, and
then **verifies with Gatekeeper against a quarantined copy** before publishing
anything. That last check is the point: `codesign --verify` passing does not mean
the app opens, because it never looks at notarisation. Only
`source=Notarized Developer ID` proves a user can double-click the download.

Afterwards, update the Homebrew cask with the line the script prints
(`brew bump-cask-pr --version <v> itraffic`).

CI (`.github/workflows/build.yml`) deliberately builds **unsigned** and uploads
a universal test DMG as a workflow artifact. It verifies compilation and disk
image integrity, not signing, notarisation or Gatekeeper acceptance. The
Developer ID certificate never has to live in this public repo's secrets.

## Conventions that have bitten us

- **Rates carry their unit in the field name** (`inBytesPerSec`,
  `totalInBytesPerSec`). `nettop` runs in delta mode over a 2-second sample, so a
  frame reports bytes moved across the whole window, not a rate. Normalise once
  in `Network.parser`, at the single point where nettop numbers enter the app,
  and never re-derive downstream. Issue #28 was exactly this: the divide was
  moved up to the aggregation point, the status bar got it, the process list did
  not, and every row rendered double for three months. If you find yourself
  adding a `/ interval` anywhere else, something is already wrong.

- **The app makes exactly one network request, and only when clicked.** Checking
  for updates (`Service/UpdateChecker.swift`) hits the GitHub releases API when
  the user clicks the version number in the header — never on a timer, never at
  launch, and there is deliberately no "check automatically" preference to
  forget about. The reason is structural: iTraffic lists the network activity of
  every process including its own, so a background poll appears to users as
  unexplained traffic from the one tool whose job is to explain traffic. Keep
  any future network work on the same rule.

- **`.help(_:)` is macOS 11+** while the deployment target is 10.15. Guard new
  API with `#available` rather than raising the target.

- **Size SF Symbols with `.font`, never `.resizable()`** — resizing stretches
  them into thin sticks at menu-bar sizes. A Unicode glyph in a `Text` avoids
  the question entirely and works on 10.15.
