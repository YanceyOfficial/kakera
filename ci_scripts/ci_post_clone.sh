#!/bin/sh
set -eu

# Xcode Cloud checks the generated workspace after this post-clone step.
# Keep the editor bundle and Tuist projects generated from the checked-out source.
export HOMEBREW_NO_AUTO_UPDATE=1

if ! command -v bun >/dev/null 2>&1; then
    brew install oven-sh/bun/bun
fi
if ! command -v tuist >/dev/null 2>&1; then
    brew install --cask tuist
fi
if ! command -v node >/dev/null 2>&1 || ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 24 ? 0 : 1)'; then
    brew install node@24
    export PATH="$(brew --prefix node@24)/bin:$PATH"
fi

hikki_repository_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${CI_PRIMARY_REPOSITORY_PATH:-$hikki_repository_dir}"

bun install --frozen-lockfile
tuist install
make generate
