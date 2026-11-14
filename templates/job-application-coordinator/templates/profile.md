# Profile

Fill in every section. The agent fills forms only from answers.md, resume.md and this file, in that order.

## Target roles

- Titles: <e.g. Backend Engineer, Platform Engineer>
- Seniority: <e.g. mid, senior>
- Work setup: <remote / hybrid / on-site>
- Locations: <cities or regions you accept>
- Employment type: <full-time / contract>

## Pre-filter

Checked against each posting's title, location and work setup as the source lists them, before the agent opens the full description. A clear miss is skipped with a short reason and the description is never read. When the listing is unclear, the posting goes to the normal fit check.

- Skip titles containing: <e.g. sales, intern, director>
- Accept locations: <e.g. remote in your country, or your cities; "any" to skip this check>
- Accept work setups: <remote / hybrid / on-site; "any" to skip this check>

## Strengths

- <skill or area you want to lead with>
- <skill or area>

## Must have

Each must-have the description clearly meets adds 2 to the score. A must-have the description clearly rules out is a no fit.

- <e.g. remote option>

## Preferences

Nice to have. Each one the description clearly meets adds 1 to the score.

- <e.g. a team that works in Go>
- <e.g. pay listed in the posting>

## Score

After the fit check, every fitting posting gets a plain score: 2 points per must-have and 1 point per preference that the description clearly meets, nothing for unclear ones, at most 100. The agent fills forms in score order, highest first, until the daily cap, and shows each score and its reason in the digest.

## Deal-breakers

Skip any posting that matches one of these.

- <e.g. requires relocation>
- <e.g. requires a clearance you do not hold>
- <e.g. pay below your floor, if the posting lists pay>

## Resume

- Resume text: in resume.md. The agent fills work history, education and skills from it.
- Resume file: <filled in by the agent during setup>
  - This is the file the agent uploads when a form asks for one.
  - To set it, send your resume file (PDF or DOCX) to this agent as a chat attachment, in the Control UI or a chat app. The agent writes the reference it receives here. You do not need to know where the file is stored.
  - A terminal chat cannot attach files, and OpenClaw's browser tool uploads only chat attachments, not a path on disk. If you only use a terminal, use the devtools-mcp driver below: it reads the resume from a normal folder.
  - OpenClaw keeps chat attachments unless your config sets `attachments.ttlHours`. If an upload fails, the agent tells you; send the file again.
  - The agent stops the run if no file is named here. A posting whose upload fails is skipped. Two failed uploads in a row end the run.
- Resume copy for the devtools-mcp driver: <blank>
  - Only needed when settings.md has `browser_driver: devtools-mcp`. That server can upload only files in `~/job-application-coordinator-files` on the Gateway host. Setup has you copy your resume there once; put its full path here, the one the setup command prints (your home folder, then `job-application-coordinator-files/resume.pdf`).
  - The copy stays across restarts. Copy again only when your resume changes. If an upload fails, the agent tells you.
