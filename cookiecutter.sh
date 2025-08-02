#!/bin/bash

# Gebruik:
# `# ./cookiecutter.sh <projectnaam>`

# Controleer of er een projectnaam is opgegeven
if [ -z "$1" ]; then
  echo "❌ Geef een projectnaam op als argument aan het script."
  exit 1
fi

# Controleer of de juiste commando's beschikbaar zijn
# swift
if ! type "swift" > /dev/null; then
  echo "❌ Please install the Swift Language"
fi

# git
if ! type "git" > /dev/null; then
  echo "❌ Please install the git cli"
fi

# github
if ! type "gh" > /dev/null; then
  echo "❌ Please install Github cli (gh)"
fi

# swiftlint
if ! type "swiftlint" > /dev/null; then
  echo "❌ Please install swiftlint"
fi

# gnu sed
if ! type "gsed" > /dev/null; then
  echo "❌ Please install gnu sed"
fi

DIRECTORY="$1"
SWIFT_IDIOMATIC_NAME=$(echo "$1" | gsed -r 's/(^|_|-|[[:space:]])(.)/\U\2/g')

# Maak een nieuwe directory voor het project
mkdir "$DIRECTORY"
cd "$DIRECTORY" || exit
echo "✅ Successfully created new project directory"


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

echo ""

# Creeer een README.md
cat <<EOT > README.md
# $SWIFT_IDIOMATIC_NAME

[![codecov](https://codecov.io/gh/wouterwietses/$DIRECTORY/graph/badge.svg)](https://codecov.io/gh/wouterwietses/$DIRECTORY)

EOT

# Creeer een BACKLOG.md
cat <<EOT > BACKLOG.md
# Backlog
EOT

# Creeer een NOTES.md
cat <<EOT > NOTES.md
# Pomodoro Technique - 📝 Notes from the journey 🍅 by 🍅

## 🏷️ Labels

- ✅ done
- 🚧 WIP
- ❌ ERROR
- ⚠️ TODO

## 🍅 Pomodoro 1
EOT

# Creeer een TECHDEBT.md
cat <<EOT > TECHDEBT.md
# Tech debt
EOT

# Creeer een LICENSE
cat <<EOT > LICENSE
MIT License

Copyright (c) 2025 Wouter Wietses

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOT

echo "✅ Successfully created template README.md, NOTES.md, TECHDEBT.md and LICENSE"

echo ""

echo "Replace generated .gitignore"
curl -o ./.gitignore https://www.toptal.com/developers/gitignore/api/macos,swift,node

# Initialize an empty git and perform first commit
echo "🚧 Initialize git and GitHub repository"
git init
git add .
git commit -m "Initial commit"

echo "Setup husky"
npm install --save-dev husky
npm install --save-dev @commitlint/cli @commitlint/config-conventional
npx husky init

echo "npx --no -- commitlint --edit \$DIRECTORY" > .husky/commit-msg
echo "export default { extends: ['@commitlint/config-conventional'] };" > commitlint.config.mjs

# Creeer een pre-commit hook
cat <<'EOT' > .husky/pre-commit
#!/bin/sh

echo "🔍 Running SwiftLint on staged files..."

# Find the correct SwiftLint path dynamically or set default path for Apple Silicon
SWIFTLINT_PATH=$(command -v swiftlint || echo "/opt/homebrew/bin/swiftlint")

# If SwiftLint is still not found, try another known location
if [ ! -x "$SWIFTLINT_PATH" ]; then
    SWIFTLINT_PATH="/usr/local/bin/swiftlint"  # Intel Macs (Homebrew default)
fi

# If SwiftLint is not found, print an error and exit
if [ ! -x "$SWIFTLINT_PATH" ]; then
    echo "❌ SwiftLint not found! Make sure it is installed via Homebrew:"
    echo ""
    echo "   brew install swiftlint"
    echo ""
    exit 1
fi

echo "✅ Found SwiftLint at: $SWIFTLINT_PATH"

# Get staged Swift files
staged_files=$(git diff --cached --name-only --diff-filter=ACM -- '*.swift')

# If no Swift files are staged, exit successfully
if [ -z "$staged_files" ]; then
    echo "No Swift files staged for commit."
    exit 0
fi

# Flag to track if linting fails
lint_failed=0

# Run SwiftLint only on staged files
while IFS= read -r file; do
    if [ -f "$file" ]; then
        swiftformat "$file" --quiet
        # Automatically fix issues where possible
        "$SWIFTLINT_PATH" lint "$file" --autocorrect --quiet

        # Re-stage the modified file
        git add "$file"

        # Run SwiftLint linting on the file
        "$SWIFTLINT_PATH" lint "$file" --quiet
        lint_status=$?

        # If SwiftLint found issues, print them and set failure flag
        if [ $lint_status -ne 0 ]; then
            echo "❌ SwiftLint found violations in $file. Fix them before committing."
            lint_failed=1
        fi
    fi
done <<< "$staged_files"

# If any file failed linting, block the commit
if [ $lint_failed -ne 0 ]; then
    echo "🚨 Commit blocked due to SwiftLint violations!"
    exit 1
fi

echo "✅ SwiftLint passed!"
EOT

git add .
git commit -m "chore: configured local quality gates"

echo "✅ Successfully created local quality gates"

mkdir -p .github/workflows

cat <<EOT > .github/workflows/swift.yml
name: Swift

on: [push]

jobs:
  build:
    runs-on: macos-15

    steps:
      - uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: latest-stable
      - uses: actions/checkout@v4
      - name: Build
        run: swift build
      - name: Run tests
        run: swift test --enable-code-coverage
      - name: Generate coverage report
        run: |
          CODECOV_PATH=\$(swift test --show-codecov-path)
          PROFDATA_PATH=\$(dirname "\$CODECOV_PATH")/default.profdata

          ALL_OBJECT_FILES=\$(find .build -name "*.o" -type f)
          SOURCE_OBJECT_FILES=\$(echo "\$ALL_OBJECT_FILES" | grep "$SWIFT_IDIOMATIC_NAME.build")

          xcrun llvm-cov report -instr-profile \$PROFDATA_PATH \$SOURCE_OBJECT_FILES

          mkdir coverage
          xcrun llvm-cov export --format="lcov" -instr-profile \$PROFDATA_PATH \$SOURCE_OBJECT_FILES >> coverage/lcov.info
      - name: Upload results to Codecov 
        uses: codecov/codecov-action@v5
EOT

git add .
git commit -m "chore: configured remote quality gates"

echo "✅ Successfully created remote quality gates"

# gh repo create $1 --public --source=. --remote=upstream
# git remote add origin https://github.com/wouterwietses/$1.git
# git push -u origin main
# echo "✅ Successfully created git repo and GitHub repository"

echo ""

echo "✅ Swift PM project '$1' succesvol aangemaakt met een executable en tests."
