# Profile

Fill in every section. The agent fills forms only from answers.md, resume.md and this file, in that order.

## Target roles

- Titles: <e.g. Backend Engineer, Platform Engineer>
- Seniority: <e.g. mid, senior>
- Work setup: <remote / hybrid / on-site>
- Locations: <cities or regions you accept>
- Employment type: <full-time / contract>

## Strengths

- <skill or area you want to lead with>
- <skill or area>

## Must have

- <e.g. remote option>

## Deal-breakers

Skip any posting that matches one of these.

- <e.g. requires relocation>
- <e.g. requires a clearance you do not hold>
- <e.g. pay below your floor, if the posting lists pay>

## Resume

- Resume text: in resume.md. The agent fills work history, education and skills from it.
- Resume file: <file reference the browser tool can upload>
  - This is the file the agent uploads when a form asks for one.
  - The browser tool uploads only from two places. Use one:
    - A path in the OpenClaw temp uploads folder on the browser host, for example `/tmp/openclaw/uploads/resume.pdf`.
    - A `media://inbound/<id>` reference: send the file to this agent in chat and paste the reference it gives you.
  - The temp folder can be cleared on restart. Put the file back if an upload fails.
  - The agent stops the run if no file is named here. A posting whose upload fails is skipped. Two failed uploads in a row end the run.
