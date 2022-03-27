FROM node:16-alpine

COPY package*.json ./
RUN npm ci --prod

COPY . . 

EXPOSE 3000
CMD [ "node", "./src/app.js" ]