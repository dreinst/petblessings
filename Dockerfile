# Situs Pet Blessing di VPS (Coolify). Vercel memakai api/*.js langsung; di sini vps/server.js.
FROM node:22-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev --no-audit --no-fund
COPY . .
USER node
EXPOSE 3000
CMD ["node", "vps/server.js"]
