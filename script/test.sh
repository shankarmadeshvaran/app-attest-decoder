#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
./script/test_assertion.sh
./script/test_persistence.sh
/usr/bin/python3 -m unittest discover -s Tests -v
