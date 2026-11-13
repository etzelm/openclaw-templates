# Example: setup dry run digest

From a real 0.2.0 setup dry run on an isolated test instance, against one public company job board, with a made-up test persona. Company names, links and the board's host are replaced. Nothing was submitted: no form was filled, because no posting fit.

**Run digest: dry run, 19:26 to 19:47**

**Applied:** none.

**Waiting for owner:** none. No CAPTCHA, no confirm wait.

**Skipped (3):**
- Example Co, Senior Data Engineer, Ads: requires 5+ years of ads data engineering; the resume shows backend Go and Python only.
- Example Co, Staff Software Engineer, Enterprise Platform: staff level, requires deep IAM (SSO, SCIM, OAuth, RBAC), Terraform and device management; not in the resume.
- Example Co, QA/DevOps Engineer: ERP and CRM test automation; no matching experience.

**Duplicates:** 0. **Flagged answers:** none.

**New questions for answers.md:** "Why do you want to work at Example Co?" is a required free-text question on every posting from this board. No file answers it, so `unknown_question: skip` would have skipped every posting even after a fit.

**Sites dropped:** none. The board listed 25 jobs; 3 were remote engineering candidates, the rest were design, finance, legal, management or on-site only.

**Why the run ended:** no fitting postings left on the listed source, and a dry run never widens searches.

## The tracker after the run

| date | company | title | link | status | note |
| ---- | ------- | ----- | ---- | ------ | ---- |
| 2026-11-12 | Example Co | QA/DevOps Engineer | https://jobs.example.com/3 | skipped | no fit: ERP and CRM test automation |
| 2026-11-12 | Example Co | Staff Software Engineer, Enterprise Platform | https://jobs.example.com/2 | skipped | no fit: staff-level platform role |
| 2026-11-12 | Example Co | Senior Data Engineer, Ads | https://jobs.example.com/1 | skipped | no fit: ads data engineering |

(The real tracker also has the fit reason, flagged answers and a description excerpt for each row.)

## What setup did next

The agent showed this digest, suggested adding an owner-written answer for the motivation question in answers.md and adding backend-focused sources, and offered to repeat the dry run before the owner picks autopilot or confirm mode.
