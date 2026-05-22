import type { Logger } from "../logger.js";
import { DISPATCH_TIMEOUT } from "../diagnostics/errors.js";

type Entry = {
  readonly resolve: (v: unknown) => void;
  readonly reject: (e: unknown) => void;
  readonly timer: ReturnType<typeof setTimeout>;
};

export class PendingRequests {
  private readonly map = new Map<number, Entry>();

  constructor(private readonly log: Logger) {}

  dispose(): void {
    for (const [, e] of [...this.map]) {
      clearTimeout(e.timer);
      e.reject(new Error("pending_disposed"));
    }
    this.map.clear();
  }

  create(
    id: number,
    method: string,
    timeoutMs: number,
    runSend: () => void,
    signal: AbortSignal | undefined,
  ): Promise<unknown> {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        if (!this.map.has(id)) return;
        clearTimeout(timer);
        this.map.delete(id);
        const ex = new Error(DISPATCH_TIMEOUT);
        (ex as NodeJS.ErrnoException).code = "-33999";
        this.log("warn", "dispatch", "request_timeout", { id, method });
        reject(ex);
      }, timeoutMs);

      const entry: Entry = {
        resolve,
        reject,
        timer,
      };

      const onAbort = (): void => {
        if (!this.map.has(id)) return;
        clearTimeout(timer);
        this.map.delete(id);
        reject(signal?.reason instanceof Error ? signal.reason : new Error("Aborted"));
      };
      signal?.addEventListener("abort", onAbort, { once: true });

      this.map.set(id, entry);
      try {
        runSend();
      } catch (err) {
        clearTimeout(timer);
        this.map.delete(id);
        signal?.removeEventListener("abort", onAbort);
        reject(err);
      }
    });
  }

  resolve(id: number, result: unknown): void {
    const e = this.map.get(id);
    if (!e) {
      this.log("info", "dispatch", "late_result_dropped", { id });
      return;
    }
    clearTimeout(e.timer);
    this.map.delete(id);
    e.resolve(result);
  }

  rejectRpc(id: number, err: unknown): void {
    const e = this.map.get(id);
    if (!e) {
      this.log("info", "dispatch", "late_error_dropped", { id });
      return;
    }
    clearTimeout(e.timer);
    this.map.delete(id);
    e.reject(err);
  }

  rejectAll(err: Error): void {
    for (const [, e] of [...this.map]) {
      clearTimeout(e.timer);
      e.reject(err);
    }
    this.map.clear();
  }
}
