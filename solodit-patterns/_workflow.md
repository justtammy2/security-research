# Solodit Note Workflow

Follow these steps every time. Code first, then write.

## 1. Protocol check (30 sec)

Google the protocol name. One sentence: what is it? (Lending, perps, AMM, vault, staking, etc.) Skip if you already know.

Why: you can't reason about attacker benefit without knowing what the protocol does.

## 2. Read the finding on Solodit

- Summary
- Vulnerability Detail

Get the concept. Don't write yet.

## 3. Read the vulnerable code

Open the GitHub source link from the finding. Read the actual vulnerable function(s). Every line. Not skim.

Non-negotiable. Notes written without reading code are summaries, not patterns.

## 4. Write the note

Structure:

**Pattern:** One-sentence shape. Strip protocol-specific words. Should generalize.

**Sniff test:** A question you'd ask while reading unfamiliar code that would make you suspect this bug. Must be answerable from code alone.

**Code shape:**

- One-line causal link (why the two pieces interact to cause the bug)
- Real snippet(s) from the source, in a `solidity` fenced block

**Instances:**

- Protocol — Finding ID (Platform, Date)
- Solodit link
- GitHub source link

## 5. Push

```bash
git add patterns/<domain>/<note-name>.md
git commit -m "Add note: <short description>"
git push
```

## Naming

Files: `patterns/<domain>/<kebab-case-shape>.md`

- 3-6 words
- Names the mechanic, not the protocol
- Examples: `missing-l2-sequencer-uptime-check.md`, `shared-heartbeat-across-feeds.md`, `expired-oracle-treated-as-valid.md`

## Anti-patterns

- Writing pattern shape before reading the code
- Naming the protocol instead of the shape
- Sniff tests that restate the bug ("does this contract have the bug?")
- Code shape in prose when a snippet exists
