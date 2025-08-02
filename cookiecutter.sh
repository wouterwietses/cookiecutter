#!/bin/bash

CREATE_SPM="$PWD/scripts/create-spm-project.sh"
CREATE_DOCS="$PWD/scripts/create-docs.sh"

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

sh $CREATE_SPM $SWIFT_IDIOMATIC_NAME

echo ""

sh $CREATE_DOCS $DIRECTORY $SWIFT_IDIOMATIC_NAME

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
