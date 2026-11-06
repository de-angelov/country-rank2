# FunScript dogfooding

Observed against the bundled FunScript build from commit `5d6231a`.

## Working: Vite and React Router routes

All four route entries are FunScript files. The Vite plugin compiles them in place and resolves JavaScript-style imports to FunScript sources; React Router strips server-only loader and action dependencies from the browser build. The build rejects `.server.*` modules in client chunks. A generated type view under `.funscript/types` allows React Router's type generation and TypeScript to resolve `.fun` and `.funx` imports without declarations alongside application files.

Native side-effect imports also work: `app/root.funx` imports the CSS directly. The former JavaScript route adapters have been removed.

## Optional inputs

Optional parameters now become real Effect `Option` values inside FunScript, and defaulted parameters accept omitted or `undefined` arguments. `SchemaInput<Name>` exposes a schema's encoded input type without implicitly decoding it; schema defaults are now applied during actual decoding. The ranking helpers and country/list components use these features. Optional handling does not validate values supplied by JavaScript; schema decoding is still required for runtime validation.

Inline record parameters now support optional callback props and produce real Effect `Option` values inside FunScript. The ranking controls use this syntax. For safety, the compiler currently rejects passing, returning, aliasing, or indexing a whole record containing optional fields except when passing it directly to an explicit `js` call. This prevents raw optional values from escaping into FunScript but makes ordinary props forwarding inconvenient. Named and nested optional record types are not yet supported.

The app type check now passes. The ranking components declare a required props object whose individual fields are optional, allowing React's component overloads to infer the props correctly. The top-liked loader declares its optional injected dependencies and accepts omitted loader arguments. Its optional inputs must currently be unpacked and reconstructed when forwarded; named optional record types and general props forwarding remain open language gaps. Further work also needs to distinguish missing, `undefined`, and `null` where the API requires it.

The previously reported invalid arrow-function fallback now emits parentheses and passes a regression test.

## Open: escape-hatch checking

The project-level `npm run check:idiomatic` reports locations for non-ambient `ts {}` blocks using the FunScript lexer. It deliberately fails while the remaining blocks exist. The checker imports an internal compiler module; a stable public API or compiler diagnostic would remove that coupling.

## Remaining migration

Larger TypeScript escape blocks remain in the ranking route components, home helpers, votes, Redis, totals, and logger modules, along with TypeScript UI, configuration, framework adapter, and test files. These need behavior-preserving conversions. TypeScript diagnostics from the generated type view may refer to cache paths rather than original FunScript locations.
