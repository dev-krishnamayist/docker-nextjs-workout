# syntax=docker/dockerfile:1

ARG NODE_VERSION=24.14.0-slim
ARG NGINX_VERSION=alpine3.22

FROM node:${NODE_VERSION} AS dependencies

WORKDIR /app

COPY package.json package-lock.json* ./

RUN --mount=type=cache,target=/root/.npm \
    if [ -f package-lock.json ]; then \
        npm ci --no-audit --no-fund; \
    else \
        echo "No lockfile found" && exit ; \
    fi

# Build Next.js Application


FROM node:${NODE_VERSION} AS builder

WORKDIR /app

COPY --from=dependencies /app/node_modules ./node_modules

COPY . .

ENV NODE_ENV=production

RUN --mount=type=cache,target=/app/.next/cache \
    if [ -f package-lock.json ]; then \
        npm run build; \
    else \
        echo "No lockfile found" && exit 1; \
    fi


# Deploy on Nginx with Next.js static files

FROM nginxinc/nginx-unprivileged:${NGINX_VERSION} AS runner

WORKDIR /app

COPY nginx.conf /etc/nginx/nginx.conf

COPY --from=builder /app/out /usr/share/nginx/html

USER nginx

EXPOSE 8080

ENTRYPOINT ["nginx", "-c", "/etc/nginx/nginx.conf"]
CMD ["-g", "daemon off;"]