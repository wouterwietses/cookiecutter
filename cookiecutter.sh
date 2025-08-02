#!/bin/bash

CREATE_SPM="$PWD/scripts/create-spm-project.sh"
CREATE_PACKAGE_JSON="$PWD/scripts/create-package-json.sh"
CREATE_CONTAINER="$PWD/scripts/create-container.sh"
CREATE_DOCS="$PWD/scripts/create-docs.sh"
CREATE_GIT="$PWD/scripts/create-git.sh"

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
SWIFT_VERSION="6.1"

# Maak een nieuwe directory voor het project
mkdir "$DIRECTORY"
cd "$DIRECTORY" || exit
echo "✅ Successfully created new project directory"

sh $CREATE_SPM $SWIFT_IDIOMATIC_NAME $SWIFT_VERSION
sh $CREATE_PACKAGE_JSON $DIRECTORY
sh $CREATE_CONTAINER $DIRECTORY $SWIFT_VERSION
sh $CREATE_DOCS $DIRECTORY $SWIFT_IDIOMATIC_NAME
sh $CREATE_GIT $DIRECTORY $SWIFT_IDIOMATIC_NAME

echo "✅ Swift PM project '$SWIFT_IDIOMATIC_NAME' succesvol aangemaakt met een executable en tests."
