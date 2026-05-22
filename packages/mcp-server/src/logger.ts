import type { Config, LogLevel } from "./config.js";

const ORDER: Record<LogLevel, number> = {
  debug: 10,
  info: 20,
  warn: 30,
  error: 40,
};

export type Logger = (
  level: LogLevel,
  subsystem: string,
  event: string,
  fields?: Record<string, unknown>,
) => void;

export function createLogger(cfg: Pick<Config, "logLevel">): Logger {
  const min = ORDER[cfg.logLevel];
  return (level, subsystem, event, fields) => {
    if (ORDER[level] < min) return;
    const rec: Record<string, unknown> = {
      ts: new Date().toISOString(),
      level,
      subsystem,
      event,
      ...fields,
    };
    process.stderr.write(`${JSON.stringify(rec)}\n`);
  };
}
