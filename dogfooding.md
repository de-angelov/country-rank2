# FunScript dogfooding

Observed against the bundled FunScript compiler from commit `886559d`.

## Working: Vite and React Router routes

All four route entries are FunScript files. The Vite plugin compiles them in place and resolves JavaScript-style imports to FunScript sources; React Router strips server-only loader and action dependencies from the browser build. The build rejects `.server.*` modules in client chunks. A generated type view under `.funscript/types` allows React Router's type generation and TypeScript to resolve `.fun` and `.funx` imports without declarations alongside application files.

Native side-effect imports also work: `app/root.funx` imports the CSS directly. The former JavaScript route adapters have been removed.

## Open: optional parameters and record fields

`npm run typecheck` now resolves the FunScript modules, revealing APIs whose actual optional inputs cannot be represented by the current FunScript syntax. For example, `CountryCard` accepts an omitted `className`, ranking helpers accept an omitted order, and loaders accept omitted arguments. The parser rejects both `(order?: Unknown)` and record fields such as `{ className?: String }`. A schema field with a default describes an optional encoded input but its decoded `Type` has a required property; using that type directly for React props therefore incorrectly requires callers to provide the defaulted property.

The ranking controls support an omitted callback at runtime, including when a button is clicked, but their generated type still requires it. The top-liked loader options additionally need to describe injectable `readTotals` and fixtures. Do not suppress these errors or add companion `.d.ts` files: support for optional JavaScript-facing arguments and properties, and a native way to use a schema's input type, would allow the public types to match existing behavior.

React's `createElement` type inference also treats the existing optional-props ranking components as accepting no named props. This needs a behavior-preserving component signature during the native FunScript migration.

## Open: function expressions inside boolean expressions

A callback fallback written as `props.onOrderChange or ((nextOrder: RankingOrder) => Unit)` emitted a JavaScript expression with an unparenthesized arrow after `||`, which Vite rejected. A separate multiline function binding works. The compiler should either emit the necessary parentheses and valid return expression or report a useful error instead of generating invalid TypeScript.

## Open: escape-hatch checking

The project-level `npm run check:idiomatic` reports locations for non-ambient `ts {}` blocks using the FunScript lexer. It deliberately fails while the remaining blocks exist. The checker imports an internal compiler module; a stable public API or compiler diagnostic would remove that coupling.

## Remaining migration

Larger TypeScript escape blocks remain in the ranking route components, home helpers, votes, Redis, totals, and logger modules, along with TypeScript UI, configuration, framework adapter, and test files. These need behavior-preserving conversions. TypeScript diagnostics from the generated type view may refer to cache paths rather than original FunScript locations.
