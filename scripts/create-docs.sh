#!/bin/bash

DIRECTORY=$1
SWIFT_IDIOMATIC_NAME=$2

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
