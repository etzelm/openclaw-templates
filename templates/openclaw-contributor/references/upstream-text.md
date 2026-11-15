# Writing for upstream

These rules apply to everything that could become public: PR titles and bodies, issue bodies, comments, review replies and commit messages. The repo's PR template and CONTRIBUTING.md decide the structure. These rules decide the voice.

## Rules

- Plain, short sentences. Simple everyday words. American English, as the repo asks (CONTRIBUTING.md: "Use American English spelling and grammar in code, comments, docs, and UI strings").
- Lead with the user-visible problem and its trigger, then the fix, then the evidence.
- State facts that the diff, tests and logs support. Do not invent a user benefit for internal work.
- No em dashes or en dashes. Use a period, a comma or a colon.
- No process narration. Do not write how the work happened, who asked, or what a bot or agent said ("the bot asked me", "as requested", "I was told", "after several attempts").
- No promises to do more later ("I will follow up", "I can also add").
- No @-mentions of people or teams. Do not guess owners. The repo's forms, labels and CODEOWNERS route the work. The one exception is the repo's own bot command `@clawsweeper re-review`, alone in its comment, under a `request-review` approval.
- No questions to maintainers in comments. If maintainers must decide something, put it in the PR body in one or two short lines, such as "Maintainer decision: keep the old flag as an alias, or remove it."
- No secrets, tokens, private paths, hostnames, personal data or unrelated log lines. Redact before quoting a log.
- Keep long output in a collapsed `<details>` block or a link. Keep the summary visible.
- Commit messages: Conventional Commit subject, a short body of facts, no agent attribution trailers.

## Check before asking for approval

Run these on the body file and the title, and fix every hit. Inside a `Runtime output` fence (references/proof.md), fix a hit only by replacing the secret or personal part with a redaction marker such as `<redacted-token>`. Never retype, reword or drop the log line, and do not count the markers themselves or plain log words (`token`, a `@` in a log format) with nothing secret or personal after them as hits:

- `perl -CSD -ne 'print "$.: $_" if /[\x{2013}\x{2014}]/' <file>` finds em and en dashes.
- `grep -n '@[A-Za-z0-9]' <file>` finds mentions. Keep only code, emails in example text, or package scopes such as `@openclaw/...` that are not a mention.
- `grep -n -i 'i will\|we will\|follow up\|as requested\|the bot\|asked me\|agent said\|co-authored-by\|generated with\|as an ai' <file>` finds narration and promises.
- `grep -n -i 'token\|password\|secret\|/Users/\|/home/' <file>` finds possible leaks.
- Before a push: `git -C <checkout> log --format='%G? %ae %ce' <upstream>/<base>..<head>`. Every commit must show `commit_email` from settings.md as author and committer, never a private address, and `G` when signing is set up.

Then read the whole body once as a maintainer would. Cut any sentence that does not help them review.
