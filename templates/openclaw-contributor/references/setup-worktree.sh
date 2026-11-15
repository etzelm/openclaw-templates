#!/bin/sh
# Create a git worktree (or adopt an existing one) and set a worktree-only commit identity
# and signing in it, then check a signed test commit. One command, so it fits one exec call.
#
# Usage:
#   sh setup-worktree.sh --repo <repo> --worktree <new path> --start <ref> [--branch <name> | --detach] \
#     --name "<name>" --email <id+login@users.noreply.github.com> --signing ssh|gpg|none [--key <key>]
#   sh setup-worktree.sh --existing --worktree <path> --name ... --email ... --signing ... [--key ...]
#
# --worktree must be an absolute path. --key is the absolute path of the ssh public key (ssh) or the
# key id (gpg). Not used with none. If a step fails after the worktree was created, fix the cause and
# rerun with --existing on the same path.
# Only the new worktree gets the identity: git config --worktree, with extensions.worktreeConfig on in
# the repository. The repository's own config and every other worktree keep theirs.
# The test commit is made with git commit-tree from HEAD's tree: it is on no branch and changes nothing.
# It refuses a bare repository (shared core.bare=true): with extensions.worktreeConfig on, git would read
# that setting in every linked worktree and they would stop working.
# Prints "setup-worktree ok: ..." and exits 0, or prints the failing line and exits 1.

set -u

repo=""; wt=""; start=""; branch=""; detach=0; existing=0; name=""; email=""; signing=""; key=""

created=0
fail() {
  echo "setup-worktree failed: $*" >&2
  [ "$created" -eq 1 ] && echo "The worktree exists now: fix the cause, then run again with --existing --worktree $wt and the identity flags." >&2
  exit 1
}
need() { [ "$1" -ge 2 ] || fail "$2 needs a value"; case "$3" in --*) fail "$2 needs a value, got the flag $3" ;; esac; }

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) need $# "$1" "${2:-}"; repo="$2"; shift 2 ;;
    --worktree) need $# "$1" "${2:-}"; wt="$2"; shift 2 ;;
    --start) need $# "$1" "${2:-}"; start="$2"; shift 2 ;;
    --branch) need $# "$1" "${2:-}"; branch="$2"; shift 2 ;;
    --detach) detach=1; shift ;;
    --existing) existing=1; shift ;;
    --name) need $# "$1" "${2:-}"; name="$2"; shift 2 ;;
    --email) need $# "$1" "${2:-}"; email="$2"; shift 2 ;;
    --signing) need $# "$1" "${2:-}"; signing="$2"; shift 2 ;;
    --key) need $# "$1" "${2:-}"; key="$2"; shift 2 ;;
    -h|--help) awk 'NR > 1 && /^#/ { print; next } NR > 1 { exit }' "$0"; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[ -n "$wt" ] || fail "--worktree is required"
case "$wt" in /*) ;; *) fail "--worktree must be an absolute path, got: $wt" ;; esac
[ -n "$name" ] || fail "--name is required"
case "$email" in
  *@users.noreply.github.com) ;;
  *) fail "--email must be a GitHub noreply address (<id>+<login>@users.noreply.github.com), got: $email" ;;
esac
case "$signing" in
  ssh|gpg) [ -n "$key" ] || fail "--key is required with --signing $signing" ;;
  none) [ -z "$key" ] || fail "--key is not used with --signing none" ;;
  *) fail "--signing must be ssh, gpg or none" ;;
esac
if [ "$signing" = ssh ]; then
  case "$key" in /*) ;; *) fail "--key must be an absolute path for ssh" ;; esac
  [ -r "$key" ] || fail "cannot read the public key: $key"
  publine="$(grep -v -e '^[[:space:]]*$' -e '^#' "$key" | head -n 1)"
  case "$publine" in ssh-*|ecdsa-*|sk-*) ;; *) fail "no public key line found in $key" ;; esac
fi

if [ "$existing" -eq 1 ]; then
  if [ -n "$repo$start$branch" ] || [ "$detach" -eq 1 ]; then fail "--existing takes only --worktree and the identity flags"; fi
  [ -d "$wt" ] || fail "worktree not found: $wt"
  git -C "$wt" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not a git worktree: $wt"
else
  [ -n "$repo" ] || fail "--repo is required"
  [ -n "$start" ] || fail "--start is required"
  [ -e "$wt" ] && fail "path already exists: $wt (use --existing to adopt it)"
  if [ "$(git -C "$repo" config --type=bool --get core.bare 2>/dev/null)" = "true" ]; then
    fail "the repository config sets core.bare=true; move it to the main worktree's config.worktree first (see git help worktree), or use a non-bare clone"
  fi
  if [ -n "$branch" ] && [ "$detach" -eq 1 ]; then fail "use --branch or --detach, not both"; fi
  if [ -z "$branch" ] && [ "$detach" -eq 0 ]; then fail "--branch <name> or --detach is required"; fi
  if [ -n "$branch" ]; then
    git -C "$repo" worktree add -b "$branch" "$wt" "$start" || fail "git worktree add"
  else
    git -C "$repo" worktree add --detach "$wt" "$start" || fail "git worktree add"
  fi
  created=1
fi

# A shared core.bare=true would be read by every linked worktree once extensions.worktreeConfig is on.
if [ "$(git -C "$wt" config --type=bool --get core.bare 2>/dev/null)" = "true" ]; then
  fail "the repository config sets core.bare=true; move it to the main worktree's config.worktree first (see git help worktree), or use a non-bare clone"
fi
# git refuses worktree config when the shared config sets core.worktree.
if git -C "$wt" config --get core.worktree >/dev/null 2>&1; then
  fail "the repository config sets core.worktree; move it to config.worktree first (see git help worktree)"
fi

git -C "$wt" config extensions.worktreeConfig true || fail "set extensions.worktreeConfig"
w() { git -C "$wt" config --worktree "$1" "$2" || fail "git config --worktree $1"; }
w user.name "$name"
w user.email "$email"
case "$signing" in
  ssh)
    gitdir="$(git -C "$wt" rev-parse --absolute-git-dir)" || fail "rev-parse --absolute-git-dir"
    signers="$gitdir/allowed_signers"
    printf '%s %s\n' "$email" "$publine" > "$signers" || fail "write $signers"
    w gpg.format ssh
    w user.signingkey "$key"
    w gpg.ssh.allowedSignersFile "$signers"
    w commit.gpgsign true
    ;;
  gpg)
    w gpg.format openpgp
    w user.signingkey "$key"
    w commit.gpgsign true
    ;;
  none)
    w commit.gpgsign false
    ;;
esac

origin="$(git -C "$wt" config --show-origin --get user.email)"
case "$origin" in
  *config.worktree*"$email") ;;
  *) fail "user.email does not come from this worktree's config.worktree: $origin" ;;
esac

tree="$(git -C "$wt" rev-parse 'HEAD^{tree}')" || fail "git rev-parse HEAD^{tree}"
if [ "$signing" = none ]; then
  commit="$(git -C "$wt" commit-tree "$tree" -m "signing test")" || fail "git commit-tree"
  want="N $email $email"
else
  commit="$(git -C "$wt" commit-tree -S "$tree" -m "signing test")" || fail "git commit-tree -S (does the key sign without a prompt?)"
  want="G $email $email"
fi
line="$(git -C "$wt" log -1 --format='%G? %ae %ce' "$commit")"
[ "$line" = "$want" ] || fail "test commit $commit prints '$line', want '$want'"

[ "$(git -C "$wt" rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ] || fail "$wt is not a usable work tree after setup (git rev-parse --is-inside-work-tree)"
git -C "$wt" status --short >/dev/null 2>&1 || fail "git status fails in $wt after setup"
echo "setup-worktree ok: $wt; test commit $commit on no branch; $line"
