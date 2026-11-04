# AGENTS.md — Development Guidelines for country-rank2

Guidelines for any AI assistant or agent working in this repository.

## 1. Core Rule: Write Idiomatic FunScript (No Evasion / Cheating)

This repository is written in **FunScript** (`.fun` and `.funx` files), compiling to TypeScript and targeting Effect v4.

- **NEVER wrap application logic, components, functions, or schemas in `ts { ... }` blocks.**
- The `ts { ... }` block is restricted **strictly** to unavoidable ambient declarations (e.g. ambient JSX namespace stubs).
- Do **NOT** create companion `.d.ts` files (e.g. `app-shell.d.ts` alongside `app-shell.funx`). The compiler checks the entire project tree cleanly using `npx funscript check app/`.
- Do **NOT** put `export default` on shared UI components. Use native named exports: `export AppShell = (props: Props) => ...`.

---

## 2. FunScript Syntax Cheatsheet

### Bindings (No `const`, `let`, or `var`)
```fun
// Bindings are immutable by default:
name = "World"

// Exported bindings:
export apiKey = "sk_live_123"
```

### Functions & Arrows (`=>`)
```fun
// Functions are declared with arrow syntax:
export add = (a: Number, b: Number): Number => a + b

// Multiline function:
export greet = (name: String) =>
  message = "Hello, " + name
  message
```

### Domain Schemas (Replaces TypeScript `type` / `interface`)
```fun
export schema Country = {
  code: String,
  name: String,
  likes: Number,
  dislikes: Number
}

// Discriminated union:
export schema VoteKind = Like | Dislike

// External TypeScript types (via ts schema):
export ts schema StripeEvent = from "stripe" type "Stripe.Event"
```

### Async Operations & Effects (Replaces `async/await` and `neverthrow`)
```fun
import { Effect } from "effect"

export loadCountryTotals = (code: String) =>
  effect {
    client <- getRedisClient
    raw <- client.hgetall("country:" + code)
    => raw
  }
```

### Exhaustive Pattern Matching (Replaces `switch` / `if-else`)
```fun
title = match voteKind
  | Like => "Thumbs Up"
  | Dislike => "Thumbs Down"
```

### JSX Components (`.funx` files)
```funx
export CountryCard = (props: CountryCardProps) =>
  <div className="rounded border p-4 shadow">
    <h3 className="font-bold">{props.country.name}</h3>
    <p>Likes: {props.country.likes}</p>
  </div>
```

---

## 3. Verification Protocol

Run targeted verification during development, and project-wide checks before committing:

```bash
# 1. Typecheck all FunScript files in the project:
npx funscript check app/

# 2. Run unit & component tests:
npm test

# 3. Verify production build:
npm run build
```
