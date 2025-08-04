#!/bin/bash

SWIFT_IDIOMATIC_NAME=$1
SWIFT_VERSION=$2
TEST_OUTPUT=$3

# Maak een nieuw Swift Package project
echo "🚧 Creating a new Swift Package project"
# swift package init --type library --name $SWIFT_IDIOMATIC_NAME
echo "✅ Successfully created a new Swift Package project"

mkdir -p Sources/{$SWIFT_IDIOMATIC_NAME,Api}
mkdir -p Tests/{${SWIFT_IDIOMATIC_NAME}Tests,ApiTests}

cat <<EOT > Sources/$SWIFT_IDIOMATIC_NAME/$SWIFT_IDIOMATIC_NAME.swift
struct $SWIFT_IDIOMATIC_NAME {
    func hello() -> String {
        "$SWIFT_IDIOMATIC_NAME"
    }
}
EOT

cat <<EOT > Tests/${SWIFT_IDIOMATIC_NAME}Tests/${SWIFT_IDIOMATIC_NAME}Tests.swift
@testable import $SWIFT_IDIOMATIC_NAME
import Testing

@Test func example() async throws {
    #expect($SWIFT_IDIOMATIC_NAME().hello() == "$SWIFT_IDIOMATIC_NAME")
}
EOT

cat <<EOT > Sources/Api/entrypoint.swift
import Vapor
import Logging
import NIOCore
import NIOPosix

@main
enum Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        
        let app = try await Application.make(env)

        // This attempts to install NIO as the Swift Concurrency global executor.
        // You can enable it if you'd like to reduce the amount of context switching between NIO and Swift Concurrency.
        // Note: this has caused issues with some libraries that use `.wait()` and cleanly shutting down.
        // If enabled, you should be careful about calling async functions before this point as it can cause assertion failures.
        // let executorTakeoverSuccess = NIOSingletons.unsafeTryInstallSingletonPosixEventLoopGroupAsConcurrencyGlobalExecutor()
        // app.logger.debug("Tried to install SwiftNIO's EventLoopGroup as Swift's global concurrency executor", metadata: ["success": .stringConvertible(executorTakeoverSuccess)])
        
        do {
            try await configure(app)
            try await app.execute()
        } catch {
            app.logger.report(error: error)
            try? await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }
}
EOT

cat <<EOT > Sources/Api/routes.swift
import OpenAPIRuntime
import OpenAPIVapor
import Vapor

func routes(_ app: Application) throws {
    let transport = VaporTransport(routesBuilder: app)
    let handler = Handler()
    try handler.registerHandlers(on: transport, serverURL: URL(string: "/")!)
}
EOT

cat <<EOT > Sources/Api/configure.swift
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // register routes
    try routes(app)
}
EOT

cat <<EOT > Sources/Api/Handler.swift
import Vapor

struct Handler: APIProtocol {
    func getHealth(_ input: Operations.GetHealth.Input) async throws -> Operations.GetHealth.Output {
        return .ok(.init(body: .json(.init(status: .active))))
    }
}
EOT

cat <<EOT > Tests/ApiTests/${SWIFT_IDIOMATIC_NAME}ApiTests.swift
@testable import Api
import VaporTesting
import Testing

@Suite("App Tests")
struct ${SWIFT_IDIOMATIC_NAME}ApiTests {
    @Test("Test health check Route")
    func healthCheck() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "health", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let status: String = try res.content.get(at: "status")
                #expect(status == "ACTIVE")
            })
        }
    }
}
EOT

cat <<EOT > Sources/Api/openapi-generator-config.yaml
generate:
  - types
  - server
accessModifier: internal
namingStrategy: idiomatic
EOT

# Symlink so the generator can pick up the file.
# Sources should always be in api/openapi.yaml
WORKING_DIR=$PWD
cd Sources/Api
ln -s ../../api/openapi.yaml .
cd $WORKING_DIR

cat <<EOT > .swift-version 
$SWIFT_VERSION
EOT

# Voeg een test target toe aan de Package.swift
cat <<EOT > Package.swift
// swift-tools-version:$SWIFT_VERSION
import PackageDescription

let package = Package(
    name: "$SWIFT_IDIOMATIC_NAME",
    platforms: [
       .macOS(.v13)
    ],
    products: [
        .library(name: "$SWIFT_IDIOMATIC_NAME", targets: ["$SWIFT_IDIOMATIC_NAME"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.7.0"),
        .package(url: "https://github.com/swift-server/swift-openapi-vapor", from: "1.0.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.115.1"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
    ],
    targets: [
        .target(
            name: "$SWIFT_IDIOMATIC_NAME",
            dependencies: [],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "${SWIFT_IDIOMATIC_NAME}Tests",
            dependencies: [
                .target(name: "$SWIFT_IDIOMATIC_NAME"),
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "Api",
            dependencies: [
                .target(name: "$SWIFT_IDIOMATIC_NAME"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIVapor", package: "swift-openapi-vapor"),
            ],
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator"),
            ]
        ),
        .testTarget(
            name: "ApiTests", 
            dependencies: [
                .target(name: "Api"),
                .product(name: "VaporTesting", package: "vapor"),
            ],
            swiftSettings: swiftSettings
        ),
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("ExistentialAny"),
] }
EOT

# Creeer een pre-commit hook
cat <<EOT > .swiftlint.yml
included:
  - Sources
  - Tests
excluded:
  - .build
EOT

echo "✅ Successfully added sample test"

echo ""

echo "🚧 Perform clean build"
swift build

case $TEST_OUTPUT in
  true)
    echo "🚧 Perform test run"
    swift test
    echo "✅ Successfully built project and performed test run"
    ;;
  false)
    echo "✅ Package created"
    ;;
esac
