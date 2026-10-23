#!/bin/bash
# Installs the binaries the project's Claude Code plugins/skills rely on.
# Only runs in Claude Code on the web; local machines manage their own tools.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# clangd for the clangd-lsp plugin (C++ sources in src/ and include/)
command -v clangd >/dev/null 2>&1 || pip3 install -q clangd

# typescript-language-server for the typescript-lsp plugin
command -v typescript-language-server >/dev/null 2>&1 || npm install -g -s typescript-language-server typescript

# graphify CLI backing the /graphify skill in .claude/skills/graphify
command -v graphify >/dev/null 2>&1 || pip3 install -q graphifyy==0.9.94
