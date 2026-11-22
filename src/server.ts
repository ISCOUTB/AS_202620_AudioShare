import { createApp } from "./app.js";
import { config } from "./shared/config.js";
import { log } from "./shared/logger.js";

const app = createApp({ serveFlutterWeb: true });

const server = app.listen(config.port, () => {
  log.info("server.started", {
    port: config.port,
    env: config.env,
    databaseFile: config.databaseFile,
  });
});

// WebSocket de audio en vivo: se engancha al mismo servidor HTTP (ADR-0015).
app.locals.attachLive(server);
