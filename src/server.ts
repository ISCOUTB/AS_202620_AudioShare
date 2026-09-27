import { createApp } from "./app.js";
import { config } from "./shared/config.js";
import { log } from "./shared/logger.js";

const app = createApp({ serveFlutterWeb: true });

app.listen(config.port, () => {
  log.info("server.started", {
    port: config.port,
    env: config.env,
    databaseFile: config.databaseFile,
  });
});