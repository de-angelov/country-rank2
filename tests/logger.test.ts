import { describe, expect, it } from "vitest";
import { Effect } from "effect";
import {
  defaultLogLevel,
  logLevelEnvVar,
  redactedLogValue,
  supportedLogLevels,
  sensitiveLogRedactionPaths,
  getLogLevel,
  createApplicationLogger,
  getDefaultApplicationLogger,
  logger,
  getLogger,
  logInfo,
  logWarn,
  logError,
} from "../app/lib/logger.server.fun";

describe("logger.server", () => {
  describe("getLogLevel", () => {
    it("returns default log level when no environment is provided", () => {
      expect(getLogLevel()).toBe(defaultLogLevel);
      expect(getLogLevel(undefined)).toBe(defaultLogLevel);
      expect(getLogLevel({})).toBe(defaultLogLevel);
    });

    it("parses and normalizes configured log levels case-insensitively with trimming", () => {
      expect(getLogLevel({ [logLevelEnvVar]: "debug" })).toBe("debug");
      expect(getLogLevel({ [logLevelEnvVar]: "  WARN  " })).toBe("warn");
      expect(getLogLevel({ [logLevelEnvVar]: "ERROR" })).toBe("error");
      expect(getLogLevel({ [logLevelEnvVar]: "Trace" })).toBe("trace");
    });

    it("falls back to default log level for unsupported values", () => {
      expect(getLogLevel({ [logLevelEnvVar]: "verbose" })).toBe(defaultLogLevel);
      expect(getLogLevel({ [logLevelEnvVar]: "" })).toBe(defaultLogLevel);
    });

    it("supports all declared supportedLogLevels", () => {
      for (const level of supportedLogLevels) {
        expect(getLogLevel({ [logLevelEnvVar]: level })).toBe(level);
      }
    });
  });

  describe("createApplicationLogger", () => {
    it("creates a logger instance without options", () => {
      const appLogger = createApplicationLogger();
      expect(appLogger).toBeDefined();
      expect(typeof appLogger.info).toBe("function");
      expect(typeof appLogger.error).toBe("function");
    });

    it("creates a logger configured with custom environment", () => {
      const appLogger = createApplicationLogger({
        env: { [logLevelEnvVar]: "error" },
      });
      expect(appLogger.level).toBe("error");
    });

    it("redacts sensitive fields in logged payloads", () => {
      expect(sensitiveLogRedactionPaths).toContain("authorization");
      expect(sensitiveLogRedactionPaths).toContain("cookie");
      expect(sensitiveLogRedactionPaths).toContain("STRIPE_SECRET_KEY");

      const chunks: string[] = [];
      const stream = {
        write: (chunk: string) => {
          chunks.push(chunk);
          return true;
        },
      };

      const customLogger = createApplicationLogger({
        env: { [logLevelEnvVar]: "debug" },
        stream: stream as unknown as import("pino").DestinationStream,
      });

      customLogger.info({ authorization: "Bearer secret-token", message: "sensitive op" });
      expect(chunks.length).toBeGreaterThan(0);
      const parsed = JSON.parse(chunks[0]);
      expect(parsed.authorization).toBe(redactedLogValue);
      expect(parsed.message).toBe("sensitive op");
    });
  });

  describe("getDefaultApplicationLogger and lazy logger export", () => {
    it("returns a singleton logger instance", () => {
      const instance1 = getDefaultApplicationLogger();
      const instance2 = getDefaultApplicationLogger();
      expect(instance1).toBe(instance2);
    });

    it("delegates logger methods lazily to default instance", () => {
      expect(typeof logger.debug).toBe("function");
      expect(typeof logger.info).toBe("function");
      expect(typeof logger.warn).toBe("function");
      expect(typeof logger.error).toBe("function");

      // Verify calling logger methods does not throw
      expect(() => logger.info("test info message")).not.toThrow();
      expect(() => logger.error({ err: new Error("test") }, "test error message")).not.toThrow();
    });
  });

  describe("Effect logging helpers", () => {
    it("getLogger returns Effect that succeeds with the application logger", async () => {
      const activeLogger = await Effect.runPromise(getLogger());
      expect(activeLogger).toBe(logger);
    });

    it("logInfo, logWarn, and logError return Effects that succeed with message", async () => {
      const infoMsg = await Effect.runPromise(logInfo("info test"));
      expect(infoMsg).toBe("info test");

      const warnMsg = await Effect.runPromise(logWarn("warn test"));
      expect(warnMsg).toBe("warn test");

      const errorMsg = await Effect.runPromise(logError("error test"));
      expect(errorMsg).toBe("error test");
    });
  });
});
