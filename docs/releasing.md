# Releasing

Every project releases its own binaries from a tag. The build runs in GitHub Actions from the tagged
commit, and nothing is uploaded from a developer machine.

The steps are manual on purpose: the tag has to point at the commit `main` carries, so the last action
is always a person pushing a tag.

## Set up

```bash
cd /path/to/learning-projects
PROJECT=hello_world
VERSION="$(bash tools/release.sh "$PROJECT" --print-version)"   # re-read this after step 1
echo "$VERSION"
```

`$PROJECT` is the directory name under `projects/`. `hello_world`, `projects/hello_world` and
`./projects/hello_world` all name the same project (`tools/release.sh:84-86`).

## 1. Raise the version

```bash
bash tools/release.sh "$PROJECT" --bump patch
VERSION="$(bash tools/release.sh "$PROJECT" --print-version)"
echo "$VERSION"
```

`--bump minor` and `--bump major` work the same way, and `--set 1.4.0` names a version outright. Add
`--dry-run` to see the edits without writing them.

The script writes every file that `ci.json` lists under `version.files`
(`projects/hello_world/ci.json:12-23`), then reads them back. For `hello_world` those files are
`Cargo.toml`, `sdkconfig.defaults` and `Cargo.lock`. It refuses a dirty worktree, a version that is not
ahead of the current one, and a version whose tag already exists locally or on the origin.

It does not commit, tag or push. The tag has to point at the merged commit, so the script prints the
remaining commands and stops.

## 2. Commit the bump and open the pull request

```bash
git switch -c chore/release-$PROJECT-$VERSION
git commit -am "chore(release): $PROJECT $VERSION"
git push origin HEAD
gh pr create --fill
```

`main` requires a pull request, so the bump lands the way any other change does.

## 3. Merge, then tag the merged commit

```bash
git switch main
git pull
VERSION="$(bash tools/release.sh "$PROJECT" --print-version)"
git tag -a "$PROJECT/v$VERSION" -m "$PROJECT $VERSION" --cleanup=verbatim
git push origin "$PROJECT/v$VERSION"
```

Pushing the tag publishes. The tag names the project, so a release carries that project's assets only.
`--cleanup=verbatim` keeps the tag message as typed, and without it git strips `#` characters.

## 4. Watch the run

```bash
gh run list --event push --limit 3
gh run watch <run-id>
```

A release takes about four and a half minutes when the build cache is warm, which is the usual case.
Measured on `hello_world` with the current workflow: `prepare` 4 s, `build` 1 m 48 s to 2 m 42 s,
`emulate` 6 s and `release` 12 s.

The first run after one of the files in `cache.key_files` changes is a cold build of about six and a
half minutes, because the cache key moves with those files. `hello_world/v0.1.1` was released on a cold
cache and took 6 m 26 s from the tag push to the asset being live.

## 5. Verify what was published

```bash
curl -fsSLO "https://github.com/ESP32TV/learning-projects/releases/download/$PROJECT/v$VERSION/hello_world-esp32c3.bin"
curl -fsSLO "https://github.com/ESP32TV/learning-projects/releases/download/$PROJECT/v$VERSION/SHA256SUMS"
sha256sum -c SHA256SUMS
```

Neither request needs a token, and both the slash form of the tag and its `%2F` encoded form resolve.
Expect `hello_world-esp32c3.bin: OK`.

The asset is a merged flash image: bootloader, partition table and application in one file written at
`0x0`. To watch it run without hardware, with `esp-emu` installed:

```bash
esp-emu --chip esp32c3 --firmware hello_world-esp32c3.bin --timeout 60s --exit-on 'Hello, world!'
```

## What the workflow does

One workflow serves every project and holds no knowledge of the language. It reads
`projects/<name>/ci.json` for the container, the build environment, the cache, the version files, the
artifacts and whether an emulator chip is declared.

| Job | What it does |
|---|---|
| `prepare` | resolves the project from the tag or the dispatch input, validates `ci.json` and `ci.sh`, reads the version through `tools/release.sh --print-version` (`release.yml:125`), and rejects a tag that disagrees with it (`:131-134`) |
| `build` | starts the repository devcontainer, runs the project's own `ci.sh` in it, copies the declared artifacts and writes `SHA256SUMS` over that exact list (`:235-245`) |
| `emulate` | boots the image in esp-emulator and requires the declared console line (`:286-287`); skipped for a project whose `ci.json` names no emulator chip |
| `release` | publishes `dist/*` on a tag only, after `build` and, when it ran, `emulate` (`:293-310`) |

The container comes from `.devcontainer/`, whose base image is pinned by digest, and the project pins
its own dependencies: `Cargo.lock` for Rust, the committed `idf_component.yml` manifests for C/C++.
Anything the component manager generates, such as `managed_components/` and `dependencies.lock`, is
build output and is not committed.

Two builds of the same sources are functionally identical and not byte-identical, because ESP-IDF
embeds build metadata in the image. `SHA256SUMS` identifies a build; it does not prove a rebuild
matches.

## Before the tag

A manual run exercises the same jobs and publishes nothing:

```bash
gh workflow run release.yml --field project=$PROJECT
gh run list --event workflow_dispatch --limit 3
```

`workflow_dispatch` uses the workflow file on the default branch, so dispatch after the bump has
merged. This is the cheapest way to find a broken build before a tag exists.

## What a release carries

The files `ci.json` lists under `artifacts`, and a `SHA256SUMS` that covers exactly those files.
For `hello_world` that is one merged image, `hello_world-esp32c3.bin`.

## When it fails

Each row is a failure this repository has produced, with the fix that landed.

| Message | Cause | Fix |
|---|---|---|
| `no directory projects/projects/hello_world` | the dispatch input already carried `projects/` | the input is normalised (`release.yml:86-88`), PR #4 |
| `Permission denied (os error 13) at path "/project/target…"` | the runner's user id differed from the mount owner | the container is started with the devcontainer CLI, which maps the user, PR #6 |
| `failed to create directory '/home/esp/.cargo/registry/cache/…'` | a named volume owned by root, and the container user is `esp` | the volume was removed, PR #8 |
| `error: cannot update the lock file … because --locked was passed` | the bump raised the crate version and left `Cargo.lock` behind | the lock is declared in `version.files`, PR #15 |
| `the project is version X but the tag asks for Y` | the tag and the project disagree | cut the tag from the merged commit of the bump (`release.yml:131-134`) |
| the emulator job fails without the expected line | the image does not print what `ci.json` declares | check `emulator.exit_on`, then boot the image locally |

## Known limits

- Pull requests report no checks. The workflow runs on tags and manual dispatches only, so a green PR
  means no conflict, not that the build passed.
- Build caches are scoped to the branch or tag that created them. A tag run restores the cache saved on
  the default branch, and not the cache of another tag or of a feature branch. After a change to the
  cache configuration, prime `main` with a manual dispatch on the merged commit, or the next release
  pays for a cold build.
- The download URL names a version, and there is no per-project "latest" link, because GitHub's
  `releases/latest` is repository-wide. Pick the version explicitly.
