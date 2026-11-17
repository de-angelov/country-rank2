# FunScript dogfooding

Observed against the modern FunScript compiler release, including rest parameters, JSX prop spread, AssemblyScript kernels, and symmetric `Option` / JavaScript interop.

This app uses the checked-in `funscript-0.1.0.tgz` development build. Its version alone does not identify the compiler commit; see the tarball history when comparing results.

## Working: Vite and React Router routes

All application route entries and server actions are native FunScript files:
- `app/routes/home/home.funx`
- `app/routes/top-liked/top-liked.funx`
- `app/routes/top-disliked/top-disliked.funx`
- `app/routes/votes.server.fun`

The Vite plugin compiles them in place and resolves JavaScript-style imports to FunScript sources; React Router strips server-only loader and action dependencies from the browser build. The build rejects `.server.*` modules in client chunks. A generated type view under `.funscript/types` allows React Router's type generation and TypeScript to resolve `.fun` and `.funx` imports without declarations alongside application files.

Native side-effect imports also work: `app/root.tsx` imports CSS directly, and all former JavaScript route adapters have been removed.

## UI Components & Variadic Utilities

The application UI component library is now 100% native FunScript (`.funx`):
- `app/components/ui/button.funx`
- `app/components/ui/card.funx`
- `app/components/ui/progress.funx`

These components use React's native component contracts via `HtmlProps<Tag>` (e.g. `HtmlProps<"button">`, `HtmlProps<"div">`), library variant types via `VariantProps<typeof ...>`, and full JSX prop spreading (`{...props}`).

Utility functions have also been migrated to FunScript:
- `app/lib/utils.fun` implements the variadic `cn(...inputs)` class name merging utility natively using FunScript's rest parameters (`...inputs: Parameters<typeof cx>`) and call spread (`cx(...inputs)`).

## Optional inputs and JavaScript Interop

Optional parameters become real Effect `Option` values inside FunScript, and defaulted parameters accept omitted or `undefined` arguments:
- **Automatic boundary lowering**: When calling foreign JavaScript functions or constructing options records, the compiler inspects target TypeScript types and automatically lowers `Option<T>` to `Option.getOrUndefined` for optional/`undefined` parameters, or to `Option.getOrNull` for parameters requiring `null`.
- **Ambiguity preservation**: Callee parameters expecting `Unknown` or nested `Option` continue to strictly require an explicit choice (`Option.getOrUndefined` vs `Option.some`), ensuring dynamic data safety.
- **Exported JS bindings (`export js`)**: Functions exported to JavaScript callers cleanly support optional (`param?: Type`) and defaulted (`param: Type = default`) parameters. JavaScript callers can omit parameters or pass `undefined`, and FunScript wraps them into sound `Option<Type>` bindings with runtime Schema validation.
- **Record contracts**: Record parameters support optional callback props and produce real Effect `Option` values inside FunScript. Data schemas decode optional fields to real `Option` values and encode ordinary JavaScript optional properties.

## Escape-hatch checking: PASS

`npm run check:idiomatic` uses the FunScript lexer to reject non-ambient standalone TypeScript blocks in `app/`. It passes on the current tree:

```
PASS: no non-ambient TypeScript escape blocks found in app/.
```

Zero non-ambient TypeScript blocks remain in application code.

## Current Migration Boundary

The remaining TypeScript files in the repository are confined to framework-level entry points and toolchain configuration:
- `app/root.tsx` and `app/routes.ts`: React Router v7 application HTML shell and route tree configuration.
- `react-router.config.ts`, `vite.config.ts`, `eslint.config.js`: Tooling and build configuration.
- `tests/`: Integration test suites running via Vitest.

When updating the bundled compiler, run `npx funscript check app/`, `npm run typecheck`, `npm test`, `npm run build` and `npm run check:idiomatic`.
