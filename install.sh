#!/usr/bin/env bash
# Symlink every skill in this repo into ~/.claude/skills so they're available
# in every project. This repo stays the source of truth.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${HOME}/.claude/skills"

mkdir -p "${SKILLS_DIR}"

# A skill is any directory in the repo containing a SKILL.md.
for skill_md in "${REPO_DIR}"/*/SKILL.md; do
  [ -e "${skill_md}" ] || continue
  skill_dir="$(dirname "${skill_md}")"
  name="$(basename "${skill_dir}")"
  target="${SKILLS_DIR}/${name}"

  if [ -L "${target}" ]; then
    # Existing symlink — refresh it to point here.
    ln -sfn "${skill_dir}" "${target}"
    echo "updated  ${name} -> ${skill_dir}"
  elif [ -e "${target}" ]; then
    # A real file/dir already lives there — don't clobber it.
    echo "SKIPPED  ${name}: ${target} exists and is not a symlink"
  else
    ln -s "${skill_dir}" "${target}"
    echo "linked   ${name} -> ${skill_dir}"
  fi
done

echo "Done. Skills installed into ${SKILLS_DIR}"
