FROM node:22-alpine

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install

COPY . .
RUN npm run build:css

EXPOSE 3000

CMD ["sh", "-c", "npm run migrate && npm run seed && node src/server.js"]
