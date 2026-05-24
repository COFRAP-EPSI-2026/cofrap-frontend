# syntax=docker/dockerfile:1

# --- Stage 1 : build du bundle Vite ---
FROM node:26-alpine AS build
WORKDIR /app

# Dépendances d'abord (cache Docker tant que package.json/yarn.lock ne changent pas)
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# Code source + build de production → /app/dist
COPY . .
RUN yarn build

# --- Stage 2 : service du statique par nginx (non-root) ---
FROM nginxinc/nginx-unprivileged:1.27-alpine

LABEL org.opencontainers.image.source="https://github.com/COFRAP-EPSI-2026/cofrap-frontend" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="cofrap-frontend" \
      org.opencontainers.image.description="Frontend COFRAP — SPA Vue 3 (création de compte, authentification, renouvellement) servie par nginx (PoC MSPR TPRE912)."

# Config nginx en template : `envsubst` substitue ${OPENFAAS_GATEWAY} au démarrage.
# NGINX_ENVSUBST_FILTER limite la substitution aux variables OPENFAAS_* — les
# variables nginx natives ($uri, $host, ...) sont ainsi préservées.
ENV NGINX_ENVSUBST_FILTER="^OPENFAAS_" \
    OPENFAAS_GATEWAY="gateway.openfaas.svc.cluster.local:8080"
COPY default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html

# nginx-unprivileged écoute sur 8080 et tourne en UID 101 (non-root)
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s CMD wget --quiet --tries=1 --spider http://127.0.0.1:8080/healthz || exit 1
