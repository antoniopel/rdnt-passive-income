FROM ghcr.io/foundry-rs/foundry:latest
RUN apk add --update nodejs-current npm
WORKDIR /app
COPY . /app
RUN npm install
RUN forge compile
CMD [ "node", "./index.js" ]