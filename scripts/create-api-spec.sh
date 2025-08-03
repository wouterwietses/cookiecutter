#!/bin/bash

CONTAINER_NAME=$1
SWIFT_IDIOMATIC_NAME=$2

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

cat << EOT > api/collection/$CONTAINER_NAME/health-check.bru
meta {
  name: Health check
  type: http
  seq: 1
}

get {
  url: http://localhost:8080/health
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

cat << EOT > api/openapi.yaml
openapi: 3.1.1
info:
  title: $SWIFT_IDIOMATIC_NAME API
  version: 1.0.0
  description: $SWIFT_IDIOMATIC_NAME API
servers:
  - url: http://localhost:8080
    description: Local server host.
paths:
  /health:
    get:
      summary: Returns the status of this service
      responses:
        "200":
          description: Success response
          content:
            application/json:
              schema:
                \$ref: "#/components/schemas/HealthCheckResponse"

components:
  schemas:
    HealthCheckResponse:
      type: object
      required:
        - status
      properties:
        status:
          type: string
          enum: ["ACTIVE"]
EOT
