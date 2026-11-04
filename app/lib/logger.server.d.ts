export type ApplicationLogger = {
  debug: (...args: any[]) => void;
  info: (...args: any[]) => void;
  warn: (...args: any[]) => void;
  error: (...args: any[]) => void;
};

export declare const logger: ApplicationLogger;
export declare const logInfo: (message: string) => any;
export declare const logWarn: (message: string) => any;
export declare const logError: (message: string) => any;
