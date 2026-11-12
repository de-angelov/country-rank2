# FunScript dogfooding

Observed against a bundled local development build based on FunScript commit `c9edc5a`, including uncommitted optional-argument and AssemblyScript changes.

## Working: Vite and React Router routes

All four route entries are FunScript files. The Vite plugin compiles them in place and resolves JavaScript-style imports to FunScript sources; React Router strips server-only loader and action dependencies from the browser build. The build rejects `.server.*` modules in client chunks. A generated type view under `.funscript/types` allows React Router's type generation and TypeScript to resolve `.fun` and `.funx` imports without declarations alongside application files.

Native side-effect imports also work: `app/root.funx` imports the CSS directly. The former JavaScript route adapters have been removed.

## Optional inputs

Optional parameters now become real Effect `Option` values inside FunScript, and defaulted parameters accept omitted or `undefined` arguments. Forward an optional parameter to another optional parameter with `Option.getOrUndefined`; a supplied Option is now treated as a value rather than automatically unwrapped. `SchemaInput<Name>` exposes a schema's encoded input type without implicitly decoding it; schema defaults are now applied during actual decoding. The ranking helpers and country/list components use these features. Optional handling does not validate values supplied by JavaScript; schema decoding is still required for runtime validation.

Record parameters support optional callback props and produce real Effect `Option` values inside FunScript. The ranking controls use a named compile-time record contract. Optional fields can occur inside nested records, including an optional parent inspected through a `Some` match. Immutable aliases and passing a record without defaults to a verified local or imported FunScript function that declares optional record fields preserve the original object; named, default, and namespace imports and immutable re-export aliases are supported. Explicit `js` calls can also receive it. Other whole-record forwarding, returns, and indexing remain restricted.

The ranking components declare a required props object whose individual fields are optional, allowing React's component overloads to infer the props correctly. The top-liked route forwards its options through a namespace import to the loader without reconstructing them. Data schemas decode optional fields to real `Option` values and encode ordinary JavaScript optional properties. A record schema containing a callback or Effect type instead defines a compile-time contract; it has no runtime decoder and does not validate JavaScript input. Unrestricted forwarding remains an open gap. `funscript tsc` runs the project's TypeScript compiler and remaps errors from an up-to-date default type view; plain `tsc`, stale views, custom output directories, and watch mode do not get that mapping. Further work also needs to distinguish missing, `undefined`, and `null` where the API requires it.

The previously reported invalid arrow-function fallback now emits parentheses and passes a regression test.

## Named callback props

Named callback contracts carry type-only metadata through TypeScript declaration output. FunScript can recover optional fields when importing the resulting package, while JavaScript and React continue to receive ordinary props. Declaration tooling must preserve this metadata. These contracts currently work as direct required function parameters; nested optional records inside callbacks, containers, or unions cannot be recovered from package declarations.

The development compiler supports JSX spread, including optional-record forwarding to a statically verified FunScript component. A wrapper can reuse the named props contract, and TypeScript rejects a callback with the wrong argument type. Spreading an optional record into an unknown target remains rejected. A JSX spread creates React's normal props object; it does not promise to preserve the original object's identity.

## Open: escape-hatch checking

The project-level `npm run check:idiomatic` reports locations for non-ambient `ts {}` blocks using the FunScript lexer. It deliberately fails while the remaining blocks exist. The checker imports an internal compiler module; a stable public API or compiler diagnostic would remove that coupling.

## Remaining migration

The home server's Promise adapter, country vote-total mapping, fallback mapping, and vote storage key are now native FunScript. The remaining TypeScript is concentrated around these examples:

- `app/components/ui/{button,card,progress}.tsx` use React's native component prop types, JSX prop spreading and rest fields, and library-defined variant types. FunScript's current restrictions on whole optional records and rest parameters make preserving those wrappers' general-purpose APIs awkward.
- `app/lib/utils.ts` exposes a variadic `cn(...inputs)` API. FunScript does not yet support rest parameters.
- `app/routes/home/home.funx` now implements the router-hook fallbacks and query updates in FunScript. It uses `createSearchParams` to copy query parameters and retains the debounced search behavior. As with the disliked route, its optional props are inline rather than exported as a named raw props type.
- `app/routes/top-disliked/top-disliked.funx` now implements its interactive component in FunScript, including router fallbacks, optional props, sorting, and query updates. It uses `Effect.try` for hooks used outside their router context, validates loader data with Effect Schema, and copies query parameters with React Router's `createSearchParams`. The similar `top-liked` component still uses a TypeScript block. Exporting the old `TopDislikedProps` type remains a gap: the component's inline optional-record parameter preserves its inferred React props, but FunScript cannot yet give that callback-free JavaScript props contract a reusable name without treating it as a decoded data schema.
- `app/routes/votes.server.fun` now parses and validates requests and constructs responses in FunScript. It uses a type-only escape for the Effect-or-Promise storage boundary; the previous named TypeScript request/result aliases are no longer exported. The generic Redis cache and most vote-storage operations remain in TypeScript; Redis URL/configuration and vote country-code validation are now FunScript. `app/countries/redis-totals.server.fun` and `app/lib/logger.server.fun` also retain TypeScript for optional dependency injection and imported library types.
- Inline objects returned directly from callbacks and match arms, such as `(country) => { ...country, likes: 0 }`, are supported and used by the country vote-total mappings.
- `app/root.tsx` and `app/routes.ts` are React Router entry/configuration files; tests and build configuration also contain TypeScript. They need separate framework/tooling assessment before removal.

The `npm run check:idiomatic` check still reports six remaining non-ambient TypeScript blocks. TypeScript diagnostics from plain `tsc` or an unsupported type view may refer to cache paths rather than original FunScript locations.
