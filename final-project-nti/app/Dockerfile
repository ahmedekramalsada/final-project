# Pin specific version for stability
FROM node:18.19-alpine3.18

WORKDIR /app

# Install dependencies first for caching
COPY package*.json ./
# Use ci for clean, deterministic installs
RUN npm ci --only=production

COPY . .

# Security: Run as non-root user
USER node

EXPOSE 3000

CMD ["node", "server.js"]