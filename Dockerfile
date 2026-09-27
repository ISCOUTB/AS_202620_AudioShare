# Dockerfile de producción — backend AudioShare (Express + better-sqlite3)
#
# Construye SOLO el backend Node.js. El cliente Flutter se sirve como
# estático si existe build/web (ver src/app.ts: serveFlutterWeb); si no
# existe, cae al cliente legado en public/. Este Dockerfile no compila
# Flutter — eso se hace en el pipeline (flutter.yml) y, si se quiere sumar
# aquí, se añadiría una etapa extra con la imagen de Flutter. De momento
# despliega el backend con el cliente legado en public/, que es lo que
# necesitas para tener una URL pública funcionando esta semana.

# ---- Etapa 1: dependencias + build ----
FROM node:22-alpine AS build
WORKDIR /app

# better-sqlite3 compila un módulo nativo: hacen falta herramientas de build.
RUN apk add --no-cache python3 make g++

COPY package.json package-lock.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# ---- Etapa 2: imagen final, solo lo necesario para ejecutar ----
FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production

RUN apk add --no-cache python3 make g++ \
    && addgroup -S audioshare && adduser -S audioshare -G audioshare

COPY package.json package-lock.json ./
RUN npm ci --omit=dev && apk del python3 make g++

COPY --from=build /app/dist ./dist
COPY public ./public

# Carpeta de datos: aquí vive data/audioshare.sqlite. Se monta como volumen
# para que la base de datos sobreviva a un redeploy (ver docker-compose.yml
# y el ADR-0004: en plataformas sin volumen persistente, este dato se pierde
# en cada redeploy — es un riesgo documentado, no un olvido).
RUN mkdir -p /app/data && chown -R audioshare:audioshare /app
VOLUME ["/app/data"]

USER audioshare
EXPOSE 3000
ENV PORT=3000
ENV DATABASE_FILE=data/audioshare.sqlite

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD node -e "fetch('http://localhost:'+(process.env.PORT||3000)+'/health').then(r=>{if(r.status!==200)process.exit(1)}).catch(()=>process.exit(1))"

CMD ["node", "dist/server.js"]
