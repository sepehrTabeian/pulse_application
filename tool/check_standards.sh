#!/usr/bin/env bash
# ENF-02: run the standards checker. Usage: tool/check_standards.sh [project_root]
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec dart run "$here/check_standards.dart" "$@"
