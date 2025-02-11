# Copied from https://github.com/logseq/logseq/blob/master/Dockerfile 

# Builder image
FROM clojure:openjdk-18-tools-deps-buster as builder

ARG LOGSEQ_TAG=nightly
ARG DEBIAN_FRONTEND=noninteractive

RUN curl -sL https://deb.nodesource.com/setup_16.x | bash - && \
  apt-get install -y nodejs

RUN apt-get update && apt-get install ca-certificates && \
  wget --no-check-certificate -qO - https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
  echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
  apt-get update && \
  apt-get install -y yarn

WORKDIR /data/

COPY deps.edn ./deps.edn
# Cache clj deps
# https://medium.com/@diogok/efficient-clojure-multistage-docker-images-with-java-and-native-image-c7c80b93c8
RUN clj -e :ok

# Build for static resources
RUN git clone --depth 1 --branch $LOGSEQ_TAG --single-branch https://github.com/logseq/logseq.git
RUN cd /data/logseq && yarn && yarn release && mv ./static ./public && rm -r ./public/workspaces

# From playwright
# https://playwright.dev/docs/docker/
FROM mcr.microsoft.com/playwright:focal
RUN npm install -g pnpm --force

WORKDIR /home/logseq

COPY --from=builder /data/logseq/public ./public

COPY package.json pnpm-lock.yaml ./
RUN pnpm i

RUN cd ./public/static && yarn install && yarn rebuild:better-sqlite3

COPY publish.mjs ./

ENTRYPOINT [ "xvfb-run", "node", "publish.mjs" ]
