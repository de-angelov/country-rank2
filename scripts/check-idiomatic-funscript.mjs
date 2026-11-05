import console from "node:console";
import process from "node:process";
import { readdir, readFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";
import ts from "typescript";
import { Lexer } from "../node_modules/funscript/dist/lexer/lexer.js";

// The FunScript lexer understands nested braces, comments, strings and JSX.
// Only standalone blocks are restricted; inline `ts { Type }` annotations are not.
export function findNonAmbientBlocks(source, filename) {
  const lines = source.split(/\r?\n/);
  const tokens = new Lexer(source, filename).tokenize();
  const offenders = [];
  for (let i = 0; i < tokens.length - 1; i++) {
    const token = tokens[i];
    if (token.type !== "ts" || tokens[i + 1].type !== "TS_CODE") continue;
    const { line, column } = token.span.start;
    if (lines[line - 1].slice(0, column - 1).trim()) continue;
    const code = tokens[i + 1].value;
    const file = ts.createSourceFile("escape.ts", code, ts.ScriptTarget.Latest, true);
    const ambientJsx = file.statements.length > 0 && file.statements.every((statement) =>
      ts.isModuleDeclaration(statement) && statement.name.getText(file) === "global" &&
      statement.modifiers?.some((modifier) => modifier.kind === ts.SyntaxKind.DeclareKeyword) &&
      statement.body && ts.isModuleBlock(statement.body) && statement.body.statements.length > 0 &&
      statement.body.statements.every((child) =>
        ts.isModuleDeclaration(child) && child.name.getText(file) === "JSX" &&
        child.body && ts.isModuleBlock(child.body) && child.body.statements.every(ts.isInterfaceDeclaration)
      )
    );
    if (!ambientJsx || file.parseDiagnostics.length) offenders.push({ line, column });
  }
  return offenders;
}

async function filesUnder(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  return (await Promise.all(entries.map(async (entry) => {
    const path = `${dir}/${entry.name}`;
    return entry.isDirectory() ? filesUnder(path) : /\.funx?$/.test(entry.name) ? [path] : [];
  }))).flat().sort();
}

async function main() {
  let failed = false;
  for (const file of await filesUnder("app")) {
    for (const { line, column } of findNonAmbientBlocks(await readFile(file, "utf8"), file)) {
      console.error(`${file}:${line}:${column}: non-ambient TypeScript escape block`);
      failed = true;
    }
  }
  if (failed) process.exitCode = 1;
  else console.log("PASS: no non-ambient TypeScript escape blocks found in app/.");
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
