---
name: update-tool-versions
description: Use when the user asks to update, bump, or refresh pinned tool versions in the cote base image or extension images — the ~24 ARG *_VERSION pins and image digest pins (cosign, curlimages/curl, oven/bun), including hash recompute, per-tool commits, doc sync, and the release flow.
user-invocable: true
---

# Update Pinned Tool Versions

Bump the version pins in this repo to their newest upstream releases. This is
a long, mechanical, failure-prone task; follow the procedure exactly.

## Source of Truth

`docs/updating-tool-versions.md` is the detailed playbook: the per-tool lookup
command table, hash-recomputation URLs, and the post-bump housekeeping order.
Read it in full before starting. AGENTS.md → *Commit Conventions* and *On-Demand
Reference Docs* apply.

## Hard Rules

1. **One tool at a time, end to end.** Look up a tool's latest release, and
   only if it is newer than the pin: edit the `ARG` (plus its per-arch
   `--checksum` hashes), then commit immediately before moving to the next
   tool. Never batch tools in one commit; never fetch release info for several
   tools in parallel (one raw GitHub release JSON can overflow the session
   context).
2. **Minimal-output lookups only.** Use the exact commands from the
   docs/updating-tool-versions.md table: `gh api ... --jq .tag_name` for GitHub
   repos, `download` + `jq` for Docker Hub / go.dev / Codeberg / nodejs.org /
   npm endpoints. Never fetch full release objects, full changelogs, or asset
   lists; never use MCP `get_latest_release`/`get_release_by_tag`.
3. **No `curl`/`wget` in bash.** Non-GitHub JSON endpoints and release
   binaries go through the `download` tool into /tmp, then parse with `jq` /
   verify with `sha256sum`.
4. **Never push.** Local commits only; pushing the branch or tags is the
   user's job. Never commit anything you didn't change (docs sync is a single
   separate commit only if at least one tool actually changed).

## Procedure

1. List the current pins in `base-image/Containerfile` (`grep -n 'ARG .*_VERSION\|^FROM .*@sha256'`)
   and in each `extensions/*/Containerfile` (`PI_VERSION`, `PIG_VERSION`).
2. Build a todo list with one item per pinned tool, then check them one at a
   time per the docs table. For Pi and PiG the npm registry is the source of
   truth for what gets installed; cross-check the GitHub release tag too.
3. For each tool with a newer release:
   - Edit the global `ARG <TOOL>_VERSION` line.
   - If the tool pins per-arch SHA-256 hashes (see docs *Hash Recomputation on
     Bumps*: hash-file case vs download-and-sha256sum case), update both
     `--checksum=sha256:…` values. For digest-pinned images (cosign, curlimages/curl,
     oven/bun) update the `FROM … @sha256:…` reference.
   - Commit that one tool. Message:
     `📦 chore(<scope>): update <tool> from <old> to <new>` where `<scope>` is
     `base-image` or the extension name (`pi`, `pi-in-go`), with the required
     `Assisted-by: <agent>:<model>` trailer.
4. After all tools, if any base-image tool changed, in one commit:
   - Sync the `## Toolchain` table in `README.md` and the Toolchain bullet in
     `AGENTS.md` to match the Containerfile.
   - Bump the base-image tag in `.devfile.yaml` (and the AGENTS.md
     *Self-hosting Devfile* mention) to the next release tag.
5. Stop there. Report per tool: changed / already current, the new version,
   and the commit for each change. Do not tag, build, or push.

## Failure Handling

- If a lookup fails, retry once, then try the tool's alternate endpoint (e.g.
  tag listing with `per_page` for tools whose "latest" is a prerelease), then
  report it as skipped — keep going with the remaining tools.
- If a hash does not verify against the published hash file (or a downloaded
  asset), do not commit that tool; report the mismatch and stop.
- A tool whose "latest" release is a prerelease or that has no new stable
  release is left as-is and reported as current.
