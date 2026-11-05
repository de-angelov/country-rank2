import { describe, expect, it } from "vitest";
import { findNonAmbientBlocks } from "../scripts/check-idiomatic-funscript.mjs";

describe("FunScript escape block check", () => {
  it("reports a block with nested declarations even when the first brace closes early", () => {
    const source = 'ts {\n  type Props = { value: string };\n  const f = () => ({ value: "}" });\n}\n';
    expect(findNonAmbientBlocks(source, "test.fun")).toEqual([{ line: 1, column: 1 }]);
  });

  it("ignores inline type escapes, comments and strings", () => {
    const source = '// ts { ignored }\nname = "ts { ignored }"\nvalue = (input: ts { Record<string, { value: number }> }) => input\n';
    expect(findNonAmbientBlocks(source, "test.fun")).toEqual([]);
  });

  it("accepts only ambient JSX namespace stubs", () => {
    const ambient = 'ts {\n  declare global { namespace JSX { interface IntrinsicElements { div: unknown } } }\n}\n';
    const executable = 'ts {\n  declare global { namespace JSX { interface IntrinsicElements {} } }\n  const x = 1;\n}\n';
    expect(findNonAmbientBlocks(ambient, "test.fun")).toEqual([]);
    expect(findNonAmbientBlocks(executable, "test.fun")).toEqual([{ line: 1, column: 1 }]);
  });
});
