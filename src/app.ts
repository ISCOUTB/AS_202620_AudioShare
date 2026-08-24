import express, { type Express } from "express";
import { sessionModuleName } from "./modules/session/index.js";
import { audioModuleName } from "./modules/audio/index.js";
import { syncModuleName } from "./modules/sync/index.js";

/**
 * Composition root: el único archivo que conoce los tres módulos a la
 * vez. Los módulos entre sí no se importan unos a otros directamente;
 * si en el futuro necesitan comunicarse, ese cableado se decide y se
 * documenta aquí (o en un ADR si implica una decisión estructural).
 *
 * Por ahora no hay lógica de negocio: solo demuestra que el esqueleto
 * arranca y que los tres módulos están efectivamente conectados a la
 * aplicación, que es lo que exige la semana 3.
 */
export function createApp(): Express {
  const app = express();

  const modules = [sessionModuleName, audioModuleName, syncModuleName];

  app.get("/health", (_req, res) => {
    res.status(200).json({
      status: "ok",
      system: "AudioShare",
      modules,
    });
  });

  return app;
}
