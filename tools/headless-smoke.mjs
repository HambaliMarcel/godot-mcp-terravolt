import { HeadlessCoordinator } from "../packages/mcp-server/dist/headless/headlessCoordinator.js";

const godotBinary =
  process.env.TERRAVOLT_GODOT_BINARY ??
  "C:/Users/marce/AppData/Local/Programs/Godot/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe";
const projectPath = process.env.TERRAVOLT_PROJECT_PATH ?? "H:/Laminer/laminer";

const coordinator = new HeadlessCoordinator(
  { godotBinaryEnv: godotBinary, projectPath },
  (msg) => console.error("[headless]", msg),
  import.meta.url,
);

try {
  await coordinator.ensureSession(projectPath);
  console.log("status", coordinator.status());
  const ping = await coordinator.rpc("ping", {});
  console.log("ping", ping);
  const info = await coordinator.rpc("project.info", {});
  console.log("project.info", info);
} catch (err) {
  console.error("FAILED", err);
  process.exitCode = 1;
} finally {
  await coordinator.stop(true);
}
