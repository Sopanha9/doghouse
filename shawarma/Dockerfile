
FROM node:14.21.3-bullseye
WORKDIR /usr/src/app
# mediasoup v3.7 build expects a classic native toolchain and python on PATH.
RUN apt-get update \
	&& apt-get install -y --no-install-recommends python3 make g++ \
	&& ln -sf /usr/bin/python3 /usr/bin/python \
	&& rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json ./

RUN npm i

COPY . .

RUN npm run build

ENV NODE_ENV production
CMD [ "node", "dist/index.js" ]
USER node