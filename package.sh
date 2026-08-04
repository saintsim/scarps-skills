#!/usr/bin/env bash
# Package every skill in this repo as an individual ZIP for upload to
# claude.ai (Settings -> Features -> Skills). Skills uploaded and enabled there
# are loaded automatically by every Claude Code cloud session — web, the Claude
# mobile app, the desktop app, and `claude --cloud` — across all repos.
#
# claude.ai expects one ZIP per skill, containing a single top-level directory
# with a SKILL.md inside it.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${REPO_DIR}/dist"

command -v zip >/dev/null 2>&1 || { echo "error: zip is not installed" >&2; exit 1; }

rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

count=0
for skill_md in "${REPO_DIR}"/*/SKILL.md; do
  [ -e "${skill_md}" ] || continue
  skill_dir="$(dirname "${skill_md}")"
  name="$(basename "${skill_dir}")"

  # Zip from the repo root so the archive contains "<name>/SKILL.md", not a
  # bare SKILL.md or an absolute path.
  (cd "${REPO_DIR}" && zip -q -r "${DIST_DIR}/${name}.zip" "${name}" -x '*.DS_Store')
  echo "packaged ${name}.zip"
  count=$((count + 1))
done

echo "Done. ${count} skill(s) packaged into ${DIST_DIR}"
echo "Upload each ZIP at claude.ai -> Settings -> Features -> Skills."
