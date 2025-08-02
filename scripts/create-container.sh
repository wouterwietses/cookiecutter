#!/bin/bash

CONTAINER_NAME=$1
SWIFT_VERSION=$2

cat << 'EOT' > Dockerfile
# ================================
# Build image
# ================================
FROM swift:SWIFT-VERSION-noble AS build

# Install OS updates
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
  && apt-get -q update \
  && apt-get -q dist-upgrade -y \
  && apt-get install -y libjemalloc-dev

# Set up a build area
WORKDIR /build

# First just resolve dependencies.
# This creates a cached layer that can be reused
# as long as your Package.swift/Package.resolved
# files do not change.
COPY ./Package.* ./
RUN swift package resolve \
  $([ -f ./Package.resolved ] && echo "--force-resolved-versions" || true)

# Copy entire repo into container
COPY . .

# Build the application, with optimizations, with static linking, and using jemalloc
# N.B.: The static version of jemalloc is incompatible with the static Swift runtime.
RUN swift build -c release \
  --product Api \
  --static-swift-stdlib \
  -Xlinker -ljemalloc

# Switch to the staging area
WORKDIR /staging

# Copy main executable to staging area
RUN cp "$(swift build --package-path /build -c release --show-bin-path)/Api" ./

# Copy static swift backtracer binary to staging area
RUN cp "/usr/libexec/swift/linux/swift-backtrace-static" ./

# Copy resources bundled by SPM to staging area
RUN find -L "$(swift build --package-path /build -c release --show-bin-path)/" -regex '.*\.resources$' -exec cp -Ra {} ./ \;

# Copy any resources from the public directory and views directory if the directories exist
# Ensure that by default, neither the directory nor any of its contents are writable.
RUN [ -d /build/Public ] && { mv /build/Public ./Public && chmod -R a-w ./Public; } || true
RUN [ -d /build/Resources ] && { mv /build/Resources ./Resources && chmod -R a-w ./Resources; } || true

# ================================
# Run image
# ================================
FROM ubuntu:noble

# Make sure all system packages are up to date, and install only essential packages.
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
  && apt-get -q update \
  && apt-get -q dist-upgrade -y \
  && apt-get -q install -y \
  ca-certificates \
  libjemalloc2 \
  tzdata \
  # If your app or its dependencies import FoundationNetworking, also install `libcurl4`.
  # libcurl4 \
  # If your app or its dependencies import FoundationXML, also install `libxml2`.
  # libxml2 \
  && rm -r /var/lib/apt/lists/*

# Create a vapor user and group with /app as its home directory
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

# Switch to the new home directory
WORKDIR /app

# Copy built executable and any staged resources from builder
COPY --from=build --chown=vapor:vapor /staging /app

# Provide configuration needed by the built-in crash reporter and some sensible default behaviors.
ENV SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all,images=all,interactive=no,swift-backtrace=./swift-backtrace-static

# Ensure all further commands run as the vapor user
USER vapor:vapor

# Let Docker bind to port 8080
EXPOSE 8080

# Start the Vapor service when the image is run, default to listening on 8080 in production environment
ENTRYPOINT ["./Api"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]

EOT

# Update the swift version
sed -i -e 's/SWIFT-VERSION/'$SWIFT_VERSION'/g' Dockerfile
rm Dockerfile-e

cat << EOT > .dockerignore
.build/
.git/
.github/
.husky/
.swiftpm/
node_modules/
.gitignore
BACKLOG.md
commitlint.config.mjs
NOTES.md
package-lock.json
package.json
README.md
TECHDEBT.md
EOT

# Ohterwise variable will be expanded and only debug ends up in the final file
LOG_LEVEL='${LOG_LEVEL:-debug}'

cat << EOT > docker-compose.yml
# Docker Compose file for Vapor
#
# Install Docker on your system to run and test
# your Vapor app in a production-like environment.
#
# Note: This file is intended for testing and does not
# implement best practices for a production deployment.
#
# Learn more: https://docs.docker.com/compose/reference/
#
#   Build images: docker compose build
#      Start app: docker compose up app
#       Stop all: docker compose down
#

x-shared_environment: &shared_environment
  LOG_LEVEL: $LOG_LEVEL
  
services:
  app:
    image: $CONTAINER_NAME:latest
    build:
      context: .
    environment:
      <<: *shared_environment
    ports:
      - '8080:8080'
    # user: '0' # uncomment to run as root for testing purposes even though Dockerfile defines 'vapor' user.
    command: ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]

EOT

npm install --save-dev @usebruno/cli

mkdir -p api/collection/$CONTAINER_NAME

cat << EOT > api/collection/$CONTAINER_NAME/bruno.json
{
  "version": "1",
  "name": "$CONTAINER_NAME",
  "type": "collection",
  "ignore": [
    "node_modules",
    ".git"
  ]
}
EOT

cat << EOT > api/collection/$CONTAINER_NAME/healthcheck.bru
meta {
  name: Healthcheck
  type: http
  seq: 1
}

get {
  url: http://localhost:8080/healthcheck
  body: none
  auth: inherit
}

tests {
  test("should return 200", function () {
    expect(res.getStatus()).to.equal(200);
  });
   
  test("should contain key with value ACTIVE", function () {
    expect(res.getBody()).to.eql({
      status: "ACTIVE",
    });
  });
}
EOT

npm run docker:build
npm run docker:run
npm run test:smoke
npm run test:integration
npm run docker:stop
