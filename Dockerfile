# Dockerfile de producción — AudioShare (Flutter Web + Express + SQLite)
#
# Compila el backend Node.js y Flutter Web en etapas independientes. Express
# sirve build/web si está presente y conserva public/ como fallback.

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

# ---- Etapa 2: aplicación Flutter Web ----
FROM ghcr.io/cirruslabs/flutter:3.35.7 AS flutter-build
WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY lib ./lib
COPY web ./web
RUN flutter build web --release

# ---- Etapa 3: imagen final, solo lo necesario para ejecutar ----
FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production

RUN apk add --no-cache python3 make g++ \
    && addgroup -S audioshare && adduser -S audioshare -G audioshare

COPY package.json package-lock.json ./
RUN npm ci --omit=dev && apk del python3 make g++

COPY --from=build /app/dist ./dist
COPY --from=flutter-build /app/build/web ./build/web
COPY public ./public

# Carpeta de datos: aquí viven data/audioshare.sqlite y data/tracks/. Se monta
# como volumen para que salas y pistas sobrevivan a un redeploy (ver
# docker-compose.yml y ADR-0008).
RUN mkdir -p /app/data && chown -R audioshare:audioshare /app
VOLUME ["/app/data"]

USER audioshare
EXPOSE 3000
ENV PORT=3000
ENV DATABASE_FILE=data/audioshare.sqlite

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD node -e "fetch('http://localhost:'+(process.env.PORT||3000)+'/health').then(r=>{if(r.status!==200)process.exit(1)}).catch(()=>process.exit(1))"

CMD ["node", "dist/server.js"]
