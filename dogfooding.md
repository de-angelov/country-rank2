# FunScript dogfooding

Observed against the repository's `funscript-0.1.0.tgz` in November 2026.

## Problem summary

| Problem | Impact | Status |
| --- | --- | --- |
| Side-effect and named-default imports do not parse. | FunScript cannot directly import the root stylesheet using the forms tested, so the TypeScript root adapter must import it. | Open in the compiler. |
| React Router route modules initially included server dependencies in the browser build. | Redis and logging code appeared in client chunks, with warnings about Node built-ins. | Worked around with JavaScript route adapters and separated shared helpers; the build now rejects server modules in client chunks. |
| The normal FunScript check accepts non-ambient `ts {}` blocks, and the compiler does not expose a public lexer API for an external policy check. | Remaining TypeScript can be missed, and the local checker depends on an internal compiler module. | Local check fixed; compiler diagnostics and a stable public API remain open. |
| TypeScript tooling does not resolve this project's FunScript modules, and generated route types lack declarations for the JavaScript adapters. | `npm run typecheck` fails even though the FunScript check, tests, and production build pass. | Open tooling integration issue. |

The route adapter workaround establishes a working boundary for this application; it does not prove that native FunScript routes cannot support the same behavior with improved framework integration.

## Open: side-effect imports

`import "./app.css"` in `app/root.funx` fails `funscript check` with `Expected '{' in import declaration`. A named default import (`import { default as appStyles } from "./app.css?url"`) also fails at `default`. React Router needs the stylesheet, so it remains in the existing `app/root.tsx` framework adapter. Supporting side-effect imports would let the FunScript root own this dependency without an escape block.

## Fixed in this application: React Router server boundaries

The client build previously emitted Redis, logger, and vote storage chunks and warned about Node built-ins. Thin React Router route adapters now expose loaders and actions separately from client components; ranking helpers shared by the client and server live in independent FunScript modules. The production build rejects `.server.*` modules in client chunks. Route adapters remain JavaScript because the framework needs route exports it can statically strip from the client graph.

## Fixed in this application: escape-hatch checking

The old line-based check stopped at the first closing brace, missing nested TypeScript blocks. `npm run check:idiomatic` now uses the FunScript lexer, reports locations for all standalone non-ambient blocks, and accepts inline type escapes and ambient JSX stubs. It deliberately fails while the remaining blocks exist. This project-level check imports the compiler's internal lexer because the package does not expose it as a public API; a stable compiler diagnostic or public lexer API would remove that coupling.

## Remaining migration

Larger TypeScript escape blocks remain in the ranking route components, home helpers, votes, Redis, totals, and logger modules, along with TypeScript UI, configuration, framework adapter, and test files. They need behavior-preserving conversions.
