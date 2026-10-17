# Txx · Title in a few words

Phase N · Target: AashCore · Risk: low | medium | high · Detail: full

## Goal

One or two sentences: what exists, or what's true, when this card is done.

## Read first

- `docs/<file>.md#<section>`: why it matters for this card
- (only what's needed; the implementer reads nothing else unless stuck)

## Files

- create `Sources/<Target>/<File>.swift`
- edit `Sources/<Target>/<File>.swift`: what changes
- delete `...`
- create `Tests/<Target>Tests/<File>Tests.swift`

## Interfaces

```swift
// Exact public or internal declarations to implement: names, signatures, access levels.
```

## Steps

1. Numbered, in the order to do them.
2. Each step small enough to check.

## Rules

- The few rules from CLAUDE.md and the docs that matter most here, with links.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS`
- [ ] Tests (one `@Test` each, in `<File>Tests.swift`):
  - `nameOfTest`: concrete input → expected output
- [ ] Anything else that must be true

## Manual check

(Only if a person has to look.) What the orchestrator does, then the one question to ask, with
what the user should see.

## Out of scope

- Things a helpful implementer might be tempted to add. Don't.

## Notes

- Pitfalls, hints, links to the gotchas.
