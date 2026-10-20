# syntax=docker/dockerfile:1

FROM node:16-bullseye AS build

WORKDIR /app

# Install dependencies first for better layer caching.
COPY src/TourismAgencyPage/package.json src/TourismAgencyPage/package-lock.json ./
RUN npm ci

# Copy the Angular application and build it for production.
COPY src/TourismAgencyPage/ ./
RUN npm run build -- --configuration production

FROM nginx:1.27-alpine AS runtime

COPY deploy/tourism-agency.nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist/tourism-agency /usr/share/nginx/html
RUN chmod -R a+rX /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
