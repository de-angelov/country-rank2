# FunScript escape-hatch inventory

Snapshot of `app/` for CR2-014. Ownership below is mapped from the current task
scopes in the board; it does not change application files.

## `ts {}` blocks

| Path | Finding | Owner |
| --- | --- | --- |
| `app/countries/index.fun:1` | Re-exports domain modules and types through a TypeScript block. This is module/barrel glue, not an ambient declaration or inline external type. | **Unowned**; team-lead follow-up needed. Consider adding it to CR2-015 or a focused follow-up. |
| `app/lib/redis.server.fun:6,105` | Type declarations plus Redis provider/cache implementation inside blocks; application logic is present. `:102` also uses permitted inline `ts { RedisConfig }` / `ts { RedisConnectableClient }` external-type annotations, which are not violations by themselves. | CR2-023 |
| `app/lib/logger.server.fun:7` | Logger creation, redaction, state, and helper logic inside a block. | CR2-024 |
| `app/countries/redis-totals.server.fun:6` | Type declarations and country-total merge/fallback/logging logic inside a block. | CR2-027 |
| `app/root.funx:3` | Type-only React import and CSS side-effect import inside a block. This is not an ambient declaration; route cleanup scope covers removing the non-ambient block. | CR2-020 |
| `app/root.funx:28` | `export default App` route bridge inside a block. | CR2-020 |
| `app/routes/top-liked/top-liked.funx:5` | React component, hooks, handlers, and route exports inside a block. | CR2-019 |
| `app/routes/top-liked/top-liked.server.fun:4,64` | Route types/sorting helpers and loader logic inside blocks. | CR2-019 |
| `app/routes/top-disliked/top-disliked.funx:5` | React component, hooks, handlers, and route exports inside a block. | CR2-019 |
| `app/routes/top-disliked/top-disliked.server.fun:4,64` | Route types/sorting helpers and loader logic inside blocks. | CR2-019 |
| `app/routes/home/home.funx:27` | Type declarations and hook/helper functions in a block. | CR2-018 |
| `app/routes/home/home.server.fun:4,32` | Route types/options and loader logic in blocks. | CR2-018 |
| `app/votes/storage.server.fun:4` | Vote storage types and persistence logic inside a block. | CR2-017 |
| `app/routes/votes.server.fun:6` | Vote request types, validation, and action helpers inside a block. | CR2-017 |
| `app/components/ranked-countries-list/ranked-countries-list.funx:1` | Component, helpers, types, and styling logic inside a block. | CR2-021 (active in Dev Agent 1 lane) |

The blocks containing imports/types are listed when they also contain or enable
non-ambient application code. Pure ambient declarations and permitted inline
external type annotations are not violations. No pure ambient declaration was
found in the scan.

## Companion declarations

`rg --files app | rg '\\.d\\.ts$'` returned no paths in this workspace snapshot.
The current board backlog's CR2-015 prose names nine historical declarations,
but none are present in this checkout; verify against the target branch when
that task begins.

## Shared component default exports

`app/components/ranked-countries-list/ranked-countries-list.funx` ends with
`export default RankedCountriesList` inside its `ts {}` block. CR2-021 owns this
component and should retain only the required named FunScript export, unless a
framework boundary explicitly requires a thin route wrapper. No other shared
component default export was found in the scanned `app/` sources. Defaults in
route modules (`root.funx`, `top-liked.funx`, `top-disliked.funx`) are route
integration points and are covered by CR2-020/CR2-019 respectively.

## Proposed compiler diagnostic

Add a project-level FunScript diagnostic that reports every `ts {}` block in
`.fun` and `.funx` source unless the block is syntactically limited to ambient
declarations. Report the file and start/end location, and distinguish allowed
inline external type annotations (`ts { SomeType }`) from blocks. A companion
check should flag `.d.ts` files adjacent to FunScript modules and default
exports on shared UI components. The diagnostic should explain that application
logic belongs in native FunScript and suggest a thin `.tsx` re-export only at a
framework boundary. This is a proposal only; no external issue was filed.

## Verification

- `rg -n 'ts\\s*\\{' app --glob '*.fun' --glob '*.funx'` — inspected all matches
  in context and mapped above.
- `rg --files app | rg '\\.d\\.ts$'` — no matches.
