# VULNERABILITY: Using latest tag
FROM node:latest

# VULNERABILITY: Running as ROOT
USER root

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install

# VULNERABILITY: Copying all files (including secrets/env if present)
COPY . .

# VULNERABILITY: Hardcoded Env Secrets
ENV DB_PASSWORD=password123
ENV API_SECRET=supersecretkey

EXPOSE 3000
CMD [ "npm", "start" ]