FROM 063754174791.dkr.ecr.us-east-1.amazonaws.com/node-16:latest

COPY package*.json ./
RUN npm ci --prod

COPY . . 

EXPOSE 3000
CMD [ "node", "./src/app.js" ]