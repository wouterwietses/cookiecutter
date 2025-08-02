#!/bin/bash

SWIFT_IDIOMATIC_NAME=$1

# Maak een nieuw Swift Package project
echo "🚧 Creating a new Swift Package project"
swift package init --type library --name $SWIFT_IDIOMATIC_NAME
echo "✅ Successfully created a new Swift Package project"

# Create Vapor project boilerplate
mkdir Sources/Api
mkdir Sources/Api/Controllers
mkdir Tests/ApiTests

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
import Vapor

func routes(_ app: Application) throws {
    try app.register(collection: HealthcheckController())
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

cat <<EOT > Sources/Api/Controllers/HealthcheckController.swift
import Vapor

struct HealthcheckController: RouteCollection {
    func boot(routes: any Vapor.RoutesBuilder) throws {
        let healtCheck = routes.grouped("healthcheck")
        healtCheck.get(use: status)
    }

    func status(_ req: Request) async throws -> HealthCheckResponse {
        HealthCheckResponse(status: "ACTIVE")
    }

    struct HealthCheckResponse: Content {
        let status: String
    }
}

EOT

cat <<EOT > Tests/ApiTests/${SWIFT_IDIOMATIC_NAME}ApiTests.swift
@testable import Api
import VaporTesting
import Testing

@Suite("App Tests")
struct ${SWIFT_IDIOMATIC_NAME}ApiTests {
    @Test("Test healthcheck Route")
    func healthcheck() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "healthcheck", afterResponse: { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "{\"status\":\"ACTIVE\"}")
            })
        }
    }
}
EOT

SWIFT_VERSION="6.1"

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
            ],
            swiftSettings: swiftSettings
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

echo "🚧 Perform clean build and initial test run"
# Voer schoon opzetten van het project uit voor eventuele fouten
swift build

# Voer de tests uit
swift test
echo "✅ Successfully built project and performed test run"
