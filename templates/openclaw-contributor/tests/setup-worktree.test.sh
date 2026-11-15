#!/bin/zsh
# 0.4.3: the packaged worktree setup script (references/setup-worktree.sh).
# Red on 0.4.2 (no script: the owner typed six git config lines per worktree), green on 0.4.3.
# Own HOME and git config, a throwaway ssh key, a repository whose own config has a private email.
# Usage: setup-worktree.test.sh <package dir>
set -u
PKG="${1:?package dir}"; PKG="${PKG:A}"
S="$PKG/references/setup-worktree.sh"
PASSES=0; FAILS=0
ok() { PASSES=$((PASSES + 1)); echo "PASS $1"; }
bad() { FAILS=$((FAILS + 1)); echo "FAIL $1 :: $2"; }
check() { if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1" "got '$2' want '$3'"; fi; }
if [[ ! -f "$S" ]]; then echo "FAIL packaged script exists ($S)"; echo "passed=0 failed=1"; exit 1; fi
mkdir -p "${0:A:h}/../tmp"
T="$(mktemp -d "${0:A:h}/../tmp/setupwt.XXXXXX")"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" GIT_CONFIG_NOSYSTEM=1
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_DIR GIT_WORK_TREE
mkdir -p "$HOME/.ssh"
git config --global user.name "Global Name"; git config --global user.email "global@example.invalid"
E="12345+test-user@users.noreply.github.com"
ssh-keygen -q -t ed25519 -N "" -C "$E" -f "$HOME/.ssh/signing" >/dev/null
PUB="$HOME/.ssh/signing.pub"

R="$T/repo"
git init -q -b main "$R"; git -C "$R" config user.email "private@example.invalid"
printf 'x\n' > "$R/f"; git -C "$R" add f; git -C "$R" commit -q --no-gpg-sign -m base

# 1. New branch worktree, ssh.
OUT="$(sh "$S" --repo "$R" --worktree "$T/wt-a" --start main --branch fix/a --name "Test User" --email "$E" --signing ssh --key "$PUB" 2>&1)"; RC=$?
check "new worktree with ssh signing exits 0" "$RC" 0
[[ "$OUT" == *"setup-worktree ok: $T/wt-a; test commit "*"on no branch; G $E $E" ]] && ok "prints ok with G and the noreply address twice" || bad "prints ok line" "$OUT"
check "worktree is on the new branch" "$(git -C "$T/wt-a" branch --show-current)" "fix/a"
printf 'y\n' > "$T/wt-a/g"; git -C "$T/wt-a" add g; git -C "$T/wt-a" commit -q -m "fix: a" 2>/dev/null
check "a real commit in it is signed as the noreply author" "$(git -C "$T/wt-a" log -1 --format='%G? %ae %ce')" "G $E $E"
check "the repository's own email is untouched" "$(git -C "$R" config --get user.email)" "private@example.invalid"
C0="$(git -C "$R" commit-tree "$(git -C "$R" write-tree)" -m t)"
check "the main worktree still commits as before (no identity leak)" "$(git -C "$R" log -1 --format='%G? %ae' "$C0")" "N private@example.invalid"
check "main branch did not move" "$(git -C "$R" log --oneline main | wc -l | tr -d ' ')" "1"
git -C "$R" worktree add -q -b plain "$T/wt-plain" main 2>/dev/null
C1="$(git -C "$T/wt-plain" commit-tree "$(git -C "$T/wt-plain" write-tree)" -m t)"
check "a worktree added later without the script does not inherit it (repeat per worktree)" "$(git -C "$T/wt-plain" log -1 --format='%ae' "$C1")" "private@example.invalid"

# 2. Adopt an existing worktree.
OUT="$(sh "$S" --existing --worktree "$T/wt-plain" --name "Test User" --email "$E" --signing ssh --key "$PUB" 2>&1)"; RC=$?
check "--existing adopts a plain worktree" "$RC" 0
C2="$(git -C "$T/wt-plain" commit-tree -S "$(git -C "$T/wt-plain" write-tree)" -m t)"
check "adopted worktree signs as the noreply author" "$(git -C "$T/wt-plain" log -1 --format='%G? %ae %ce' "$C2")" "G $E $E"

# 3. Detached worktree.
OUT="$(sh "$S" --repo "$R" --worktree "$T/wt-d" --start main --detach --name "Test User" --email "$E" --signing ssh --key "$PUB" 2>&1)"; RC=$?
check "--detach works" "$RC" 0
check "detached worktree has no branch" "$(git -C "$T/wt-d" branch --show-current)" ""

# 4. signing none.
OUT="$(sh "$S" --repo "$R" --worktree "$T/wt-n" --start main --branch fix/n --name "Test User" --email "$E" --signing none 2>&1)"; RC=$?
check "--signing none exits 0" "$RC" 0
[[ "$OUT" == *"N $E $E" ]] && ok "--signing none prints N and the noreply address" || bad "--signing none line" "$OUT"

# 5. Refusals.
refuses() { local name="$1"; shift; local o; o="$(sh "$S" "$@" 2>&1)"; if [[ $? -ne 0 && "$o" == *"setup-worktree failed"* ]]; then ok "refuses: $name"; else bad "refuses: $name" "$o"; fi; }
refuses "a private email" --repo "$R" --worktree "$T/x1" --start main --branch x1 --name N --email private@example.invalid --signing ssh --key "$PUB"
refuses "a relative key path" --repo "$R" --worktree "$T/x2" --start main --branch x2 --name N --email "$E" --signing ssh --key signing.pub
refuses "an existing path without --existing" --repo "$R" --worktree "$T/wt-a" --start main --branch x3 --name N --email "$E" --signing ssh --key "$PUB"
refuses "neither --branch nor --detach" --repo "$R" --worktree "$T/x4" --start main --name N --email "$E" --signing ssh --key "$PUB"
refuses "an unknown signing mode" --repo "$R" --worktree "$T/x5" --start main --branch x5 --name N --email "$E" --signing pgp --key "$PUB"
refuses "a key that cannot sign" --repo "$R" --worktree "$T/x6" --start main --branch x6 --name N --email "$E" --signing ssh --key "$HOME/.ssh/missing.pub"
refuses "a relative worktree path" --repo "$R" --worktree wt-rel --start main --branch x7 --name N --email "$E" --signing ssh --key "$PUB"
refuses "--key with --signing none" --repo "$R" --worktree "$T/x8" --start main --branch x8 --name N --email "$E" --signing none --key "$PUB"
# A flag with its value missing at the end must refuse, not loop (macOS /bin/sh: shift 2 with one argument left fails without shifting).
sh "$S" --existing --worktree "$T/wt-plain" --name N --email "$E" --signing ssh --key > "$T/hang.log" 2>&1 &
HP=$!; for i in 1 2 3 4 5 6 7 8 9 10; do kill -0 $HP 2>/dev/null || break; sleep 0.5; done
if kill -0 $HP 2>/dev/null; then kill $HP; bad "a missing value at the end refuses instead of hanging" "still running after 5 s"; else wait $HP; HR=$?; [[ $HR -ne 0 ]] && grep -q 'needs a value' "$T/hang.log" && ok "a missing value at the end refuses instead of hanging" || bad "a missing value at the end refuses" "rc=$HR $(cat "$T/hang.log")"; fi
refuses "--existing with --repo" --existing --repo "$R" --worktree "$T/wt-plain" --name N --email "$E" --signing ssh --key "$PUB"
# A public key file with a trailing newline-terminated extra line still gives one allowed_signers line.
cp "$HOME/.ssh/signing" "$HOME/.ssh/two-lines"; cp "$PUB" "$HOME/.ssh/two-lines.pub"; printf '\n' >> "$HOME/.ssh/two-lines.pub"
OUT="$(sh "$S" --repo "$R" --worktree "$T/wt-k" --start main --branch fix/k --name "Test User" --email "$E" --signing ssh --key "$HOME/.ssh/two-lines.pub" 2>&1)"; RC=$?
check "a public key file with an extra line still signs (first line used)" "$RC" 0
check "allowed_signers has exactly one line" "$(wc -l < "$(git -C "$T/wt-k" rev-parse --absolute-git-dir)/allowed_signers" | tr -d ' ')" "1"
refuses "a flag as a value (--key --name)" --repo "$R" --worktree "$T/x9" --start main --branch x9 --key --name N --email "$E" --signing ssh
cp "$HOME/.ssh/signing" "$HOME/.ssh/commented"; { printf '# my signing key\n\n'; cat "$PUB"; } > "$HOME/.ssh/commented.pub"
OUT="$(sh "$S" --repo "$R" --worktree "$T/wt-c" --start main --branch fix/c --name "Test User" --email "$E" --signing ssh --key "$HOME/.ssh/commented.pub" 2>&1)"; RC=$?
check "a key file whose first lines are a comment and a blank line still signs" "$RC" 0
printf 'not a key\n' > "$HOME/.ssh/bad.pub"
refuses "a key file with no public key line" --repo "$R" --worktree "$T/x10" --start main --branch x10 --name N --email "$E" --signing ssh --key "$HOME/.ssh/bad.pub"
[[ ! -e "$T/x1" && ! -e "$T/x4" && ! -e "$R/wt-rel" && ! -e "$T/x10" ]] && ok "a refusal creates no worktree" || bad "a refusal creates no worktree" "x1, x4, x10 or wt-rel exists"

# 6. A bare repository: refuse before creating anything, and leave the bare repo's config alone.
BARE="$T/bare.git"; git clone -q --bare "$R" "$BARE"
refuses "a bare repository" --repo "$BARE" --worktree "$T/wt-bare" --start main --branch fix/bare --name N --email "$E" --signing none
[[ ! -e "$T/wt-bare" ]] && ok "bare: no worktree created" || bad "bare: no worktree created" "$T/wt-bare exists"
check "bare: extensions.worktreeConfig not turned on" "$(git -C "$BARE" config --get extensions.worktreeConfig)" ""
# A linked worktree a person made by hand from the bare repo, then adopted: still refused.
git -C "$BARE" worktree add -q -b fix/hand "$T/wt-hand" main 2>/dev/null
refuses "--existing on a worktree of a bare repository" --existing --worktree "$T/wt-hand" --name N --email "$E" --signing none
check "bare: the hand-made worktree still works" "$(git -C "$T/wt-hand" rev-parse --is-inside-work-tree 2>&1)" "true"
grep -q 'rev-parse --is-inside-work-tree' "$S" && ok "script checks the worktree works before ok" || bad "script checks the worktree works before ok" "missing"

# 7. Text rules: one plain command, no stash.
grep -q 'git stash' "$S" && bad "script never uses git stash" "found" || ok "script never uses git stash"

echo "passed=$PASSES failed=$FAILS"
[[ $FAILS -eq 0 ]]
