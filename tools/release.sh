#!/usr/bin/env bash
# Raises one project's version in every file its ci.json declares.
#
#   bash tools/release.sh hello_world --print-version
#   bash tools/release.sh hello_world --bump patch --dry-run
#   bash tools/release.sh hello_world --bump minor
#   bash tools/release.sh hello_world --set 1.4.0
#
# The version locations live in projects/<project>/ci.json under version.files: a
# list of paths, each with a pattern whose first capture group is the version. The
# release workflow reads the same block by calling this script with
# --print-version, so the version is declared once and read by both.
#
# The script writes files and stops. It never commits, tags or pushes: the release
# tag has to point at the merged commit, so it prints the commands instead.
set -euo pipefail

usage() {
    cat <<'TEXT'
usage: bash tools/release.sh <project> (--print-version | --bump major|minor|patch | --set X.Y.Z) [--dry-run]

  <project>         directory name under projects/. projects/<name> and
                    ./projects/<name> are accepted too.
  --print-version   print the current version and exit
  --bump            raise major, minor or patch by one
  --set             set an explicit version
  --dry-run         show what would change and write nothing
TEXT
}

die() {
    printf 'release.sh: %s\n' "$*" >&2
    exit 1
}

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

project=""
action=""
target=""
dry_run=false

while [ $# -gt 0 ]; do
    case "$1" in
        --print-version)
            action=print
            shift
            ;;
        --bump)
            action=bump
            target="${2:-}"
            shift 2 || die "--bump needs major, minor or patch"
            ;;
        --set)
            action=set
            target="${2:-}"
            shift 2 || die "--set needs a version"
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            die "unknown option ${1}"
            ;;
        *)
            [ -z "${project}" ] || die "one project at a time"
            project="$1"
            shift
            ;;
    esac
done

[ -n "${project}" ] || { usage >&2; die "a project is required"; }
[ -n "${action}" ] || { usage >&2; die "pass --print-version, --bump or --set"; }

# Every other interface in this repository names a project, so take the name with
# or without the path around it.
project="${project#./}"
project="${project#projects/}"
project="${project%/}"

project_dir="projects/${project}"
[ -d "${project_dir}" ] || die "no directory ${project_dir}. Pass the directory name under projects/."

metadata="${project_dir}/ci.json"
[ -f "${metadata}" ] || die "no ${metadata}"

read_version() {
    python3 - "${metadata}" "${project_dir}" <<'PY'
import json, pathlib, re, sys

metadata, project_dir = sys.argv[1], sys.argv[2]
spec = json.loads(pathlib.Path(metadata).read_text())
files = (spec.get("version") or {}).get("files") or []
if not files:
    sys.exit(f"{metadata}: no version.files block")

seen = {}
for entry in files:
    path = pathlib.Path(project_dir) / entry["path"]
    if not path.is_file():
        sys.exit(f"{path}: declared in {metadata} but missing")
    matches = re.findall(entry["pattern"], path.read_text(), re.MULTILINE)
    if len(matches) != 1:
        sys.exit(f"{path}: the pattern matched {len(matches)} times, expected exactly 1")
    seen[str(path)] = matches[0]

versions = set(seen.values())
if len(versions) != 1:
    detail = ", ".join(f"{p}={v}" for p, v in sorted(seen.items()))
    sys.exit(f"{metadata}: declared files disagree on the version: {detail}")

print(versions.pop())
PY
}

current="$(read_version)"

if [ "${action}" = "print" ]; then
    printf '%s\n' "${current}"
    exit 0
fi

if ! printf '%s' "${current}" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    die "${metadata} reports '${current}', which is not major.minor.patch"
fi

if [ "${action}" = "set" ]; then
    printf '%s' "${target}" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' ||
        die "--set wants major.minor.patch, got '${target}'"
    new="${target}"
else
    IFS=. read -r major minor patch <<<"${current}"
    case "${target}" in
        major) new="$((major + 1)).0.0" ;;
        minor) new="${major}.$((minor + 1)).0" ;;
        patch) new="${major}.${minor}.$((patch + 1))" ;;
        *) die "--bump wants major, minor or patch, got '${target}'" ;;
    esac
fi

# The new version has to be ahead of the current one. This also stops a repeat of
# the same command from looking like a fresh bump.
if [ "${new}" = "${current}" ]; then
    die "${current} is already the current version"
fi
newer="$(
    python3 - "${current}" "${new}" <<'PY'
import sys
cur = tuple(int(p) for p in sys.argv[1].split("."))
new = tuple(int(p) for p in sys.argv[2].split("."))
print("yes" if new > cur else "no")
PY
)"
[ "${newer}" = "yes" ] || die "${new} is behind the current version ${current}"

tag="${project}/v${new}"
if git rev-parse -q --verify "refs/tags/${tag}" >/dev/null; then
    die "tag ${tag} already exists"
fi
if git ls-remote --tags origin 2>/dev/null | grep -q "refs/tags/${tag}$"; then
    die "tag ${tag} already exists on origin"
fi

if [ "${dry_run}" = false ] && [ -n "$(git status --porcelain)" ]; then
    die "the worktree has changes; commit or stash them before bumping a version"
fi

# Verify every declared file, then write, then read them back. A partial write is
# worse than a refusal, so nothing is touched until all patterns have matched.
python3 - "${metadata}" "${project_dir}" "${new}" "${dry_run}" <<'PY'
import json, pathlib, re, sys

metadata, project_dir, new_version, dry_run = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "true"
spec = json.loads(pathlib.Path(metadata).read_text())
files = (spec.get("version") or {}).get("files") or []

plans = []
for entry in files:
    path = pathlib.Path(project_dir) / entry["path"]
    text = path.read_text()
    matches = list(re.finditer(entry["pattern"], text, re.MULTILINE))
    if len(matches) != 1:
        sys.exit(f"{path}: the pattern matched {len(matches)} times, expected exactly 1")
    match = matches[0]
    old = match.group(1)
    updated = text[: match.start()] + match.group(0).replace(old, new_version, 1) + text[match.end() :]
    plans.append((path, old, updated))

for path, old, updated in plans:
    if dry_run:
        print(f"would set {path} from {old} to {new_version}")
        continue
    path.write_text(updated)
    print(f"set {path} from {old} to {new_version}")

if dry_run:
    sys.exit(0)

# Read every file back through the same patterns the release workflow uses.
for entry in files:
    path = pathlib.Path(project_dir) / entry["path"]
    matches = re.findall(entry["pattern"], path.read_text(), re.MULTILINE)
    if matches != [new_version]:
        sys.exit(f"{path}: after writing, the pattern reports {matches} instead of {new_version}")
PY

if [ "${dry_run}" = true ]; then
    printf '\nnothing was written. Run again without --dry-run to apply.\n'
    exit 0
fi

cat <<TEXT

${project} is now ${current} -> ${new}. Next:

  git switch -c chore/release-${project}-${new}
  git commit -am "chore(release): ${project} ${new}"
  # open the PR, merge it, then cut the tag from main:
  git tag -a ${tag} -m "${project} ${new}" --cleanup=verbatim
  git push origin ${tag}
TEXT
