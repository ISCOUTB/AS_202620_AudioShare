import { createApp } from "./app.js";
import { config } from "./shared/config.js";

const app = createApp();

app.listen(config.port, () => {
  console.log(`AudioShare escuchando en http://localhost:${config.port}`);
});
