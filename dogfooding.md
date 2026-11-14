# FunScript dogfooding

This app uses the checked-in `funscript-0.1.0.tgz` development build. Its version alone does not identify the compiler commit; see the tarball history when comparing results.

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

## Escape-hatch checking

`npm run check:idiomatic` uses the FunScript lexer to reject non-ambient standalone
TypeScript blocks in `app/`. It passes on the current tree. The checker imports an
internal compiler module, so a stable public API or compiler diagnostic would remove
that coupling.

## Current integration and remaining friction

- The UI wrappers live in `.funx` files and use React prop types, JSX spread and
  library-defined variants. `app/lib/utils.fun` implements the variadic `cn` helper
  with a rest parameter. The top-liked route is also implemented in FunScript.
- Optional record forwarding remains restricted to targets the compiler can verify;
  imported contract metadata has limitations for optional records nested in callback
  parameters, containers or unions. Named JavaScript props contracts and runtime
  data schemas still need careful distinction.
- TypeScript diagnostic remapping requires an up-to-date default `.funscript/types`
  view and `funscript tsc`; plain `tsc`, watch mode and custom output directories do
  not provide the same mapping.
- `app/root.tsx` and `app/routes.ts` remain React Router entry/configuration files;
  tests and build configuration also use TypeScript.

When updating the bundled compiler, run `npx funscript check app/`, `npm run
typecheck`, `npm test`, `npm run build` and `npm run check:idiomatic`. Record the
compiler commit alongside the tarball update and rerun these checks rather than
assuming the unchanged package version identifies the build.
