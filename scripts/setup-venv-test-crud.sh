#!/bin/bash
# setup-venv.sh
# Creates a Python venv and installs dependencies, then runs the CRUD test.
#
# Usage:
#   chmod +x scripts/setup-venv.sh
#   ./scripts/setup-venv.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$ROOT_DIR/.venv"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║         Python CRUD Test Setup       ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Create venv if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
  echo "  Creating virtual environment at .venv ..."
  python3 -m venv "$VENV_DIR"
  echo "  ✅ venv created"
else
  echo "  ✅ venv already exists — skipping creation"
fi

# Activate and install
echo ""
echo "  Installing dependencies from requirements.txt ..."
"$VENV_DIR/bin/pip" install --quiet --upgrade pip
"$VENV_DIR/bin/pip" install --quiet -r "$ROOT_DIR/requirements.txt"
echo "  ✅ Dependencies installed"

# Run the CRUD test
echo ""
echo "  Running CRUD tests ..."
echo ""
"$VENV_DIR/bin/python3" "$SCRIPT_DIR/test-crud.py" "$@"
