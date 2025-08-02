#!/bin/bash

CREATE_API_SPEC="$PWD/scripts/create-api-spec.sh"
CREATE_PACKAGE_JSON="$PWD/scripts/create-package-json.sh"
CREATE_SPM="$PWD/scripts/create-spm-project.sh"
CREATE_CONTAINER="$PWD/scripts/create-container.sh"
CREATE_DOCS="$PWD/scripts/create-docs.sh"
CREATE_GIT="$PWD/scripts/create-git.sh"

# Default variable values
DIRECTORY=""
SWIFT_VERSION="6.1"
TEST_OUTPUT=false

# Function to display script usage
usage() {
 echo "Usage: $0 [OPTIONS]"
 echo "Options:"
 echo " -h, --help      Display this help message"
 echo " -t, --test      Test package & docker config"
 echo " -n, --name      Name of the project (required)"
}

has_argument() {
    [[ ("$1" == *=* && -n ${1#*=}) || ( ! -z "$2" && "$2" != -*)  ]];
}

extract_argument() {
  echo "${2:-${1#*=}}"
}

# Function to handle options and arguments
handle_options() {
  while [ $# -gt 0 ]; do
    case $1 in
      -h | --help)
        usage
        exit 0
        ;;
      -t | --test)
        TEST_OUTPUT=true
        ;;
      -n | --name*)
        if ! has_argument $@; then
          echo "Name not specified." >&2
          usage
          exit 1
        fi

        DIRECTORY=$(extract_argument $@)

        shift
        ;;
      *)
        echo "Invalid option: $1" >&2
        usage
        exit 1
        ;;
    esac
    shift
  done
}

# Check if there are options provided
if [ -z "$1" ]; then
  usage
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

# Main script execution
handle_options "$@"

if [ -z "$DIRECTORY" ]; then
  usage
  exit 1
fi

SWIFT_IDIOMATIC_NAME=$(echo "$DIRECTORY" | gsed -r 's/(^|_|-|[[:space:]])(.)/\U\2/g')

# Maak een nieuwe directory voor het project
mkdir "$DIRECTORY"
cd "$DIRECTORY" || exit
echo "✅ Successfully created new project directory"

sh $CREATE_PACKAGE_JSON $DIRECTORY
sh $CREATE_API_SPEC $DIRECTORY $SWIFT_IDIOMATIC_NAME
sh $CREATE_SPM $SWIFT_IDIOMATIC_NAME $SWIFT_VERSION $TEST_OUTPUT
sh $CREATE_CONTAINER $DIRECTORY $SWIFT_VERSION $TEST_OUTPUT
sh $CREATE_DOCS $DIRECTORY $SWIFT_IDIOMATIC_NAME
sh $CREATE_GIT $DIRECTORY $SWIFT_IDIOMATIC_NAME

echo "✅ Swift PM project '$SWIFT_IDIOMATIC_NAME' succesvol aangemaakt met een executable en tests."
