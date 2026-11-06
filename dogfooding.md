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

The home server's Promise adapter, country vote-total mapping, fallback mapping, and vote storage key are now native FunScript. The remaining TypeScript is concentrated around these examples:

- `app/components/ui/{button,card,progress}.tsx` use React's native component prop types, JSX prop spreading and rest fields, and library-defined variant types. FunScript's current restrictions on whole optional records and rest parameters make preserving those wrappers' general-purpose APIs awkward.
- `app/lib/utils.ts` exposes a variadic `cn(...inputs)` API. FunScript does not yet support rest parameters.
- `app/routes/home/home.funx` still uses TypeScript for router-hook fallbacks and `new URLSearchParams(prev)`. JavaScript constructors requiring `new` currently need an interop wrapper.
- `app/routes/top-liked/top-liked.funx` and `app/routes/top-disliked/top-disliked.funx` still contain the interactive route components. They combine React hooks, optional props, and React Router values; converting them must preserve the existing behavior and inferred React types.
- `app/countries/redis-totals.server.fun`, `app/lib/redis.server.fun`, `app/votes/storage.server.fun`, and `app/lib/logger.server.fun` retain TypeScript for optional dependency-injection objects, imported library types, and APIs that rely on JavaScript construction or mutable state. `app/routes/votes.server.fun` still contains request parsing and validation over untrusted JavaScript values.
- An inline object returned directly from a callback or match arm, such as `(country) => { ...country, likes: 0 }`, produced invalid TypeScript in this build. The migrated country mappings use a named binding and an explicit return instead.
- `app/root.tsx` and `app/routes.ts` are React Router entry/configuration files; tests and build configuration also contain TypeScript. They need separate framework/tooling assessment before removal.

The `npm run check:idiomatic` check still reports the nine remaining non-ambient TypeScript blocks. TypeScript diagnostics from the generated type view may refer to cache paths rather than original FunScript locations.
