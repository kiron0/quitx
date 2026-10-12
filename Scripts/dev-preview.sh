#!/bin/bash
set -euo pipefail
exec swift "$(dirname "$0")/dev-preview.swift" "${1:-}"
