FROM node:8-alpine
RUN apk add git openssh --no-cache
ADD . /script
WORKDIR /script
RUN npm install --production
ENTRYPOINT ["node", "/script/bin.js"]
