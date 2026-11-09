# OpenClaw Templates

This repo is the source for the OpenClaw Templates that etzelm publishes on ClawHub.
A Template is a package that `openclaw templates add` turns into a new, ordinary OpenClaw agent.

Each folder under `templates/` holds one Template.
The package source sits at the root of that folder: `CLAW.md`, `package.json`, `workspace/`, `references/`, `templates/` and the rest.
`tests/` holds the database and package tests.
`scripts/` holds the release gate scripts.
Neither of those two folders goes into the published package.

Every released version is a commit on `main`, tagged `<template>@<version>`, for example `openclaw-contributor@0.4.1`.

## Published Templates

| Template | Package | ClawHub | Folder |
|----------|---------|---------|--------|
| OpenClaw contributor | `@etzelm/openclaw-contributor` | [ClawHub page](https://clawhub.ai/plugins/%40etzelm%2Fopenclaw-contributor) | `templates/openclaw-contributor/` |
| Job application coordinator | `@etzelm/job-application-coordinator` | [ClawHub page](https://clawhub.ai/plugins/%40etzelm%2Fjob-application-coordinator) | `templates/job-application-coordinator/` |

Each Template has its own `README.md` and `CHANGELOG.md` with the details.

Add one to your OpenClaw:

```sh
openclaw templates add @etzelm/openclaw-contributor
```

## Report a problem

Open a GitHub issue in this repo with the bug form.
Give the Template name, its version, your OpenClaw version (`openclaw --version`) and what happened.
Do not paste tokens, keys or personal data.

## Build or check a Template locally

You need OpenClaw with the `templates` command, and `sqlite3` and `zsh` for the tests.

```sh
cd templates/openclaw-contributor
openclaw templates validate .
openclaw templates dev .
openclaw templates build . --out ../../dist/openclaw-contributor.tgz
```

`validate` lists the files it leaves out of the package, such as `tests/` and `scripts/`.
`dev` checks what an Add would do without changing your OpenClaw.
`build` refuses to overwrite an existing file.

Run the database tests from the repo root. Each test takes the package folder:

```sh
zsh templates/openclaw-contributor/tests/occ-approval-sha.test.sh templates/openclaw-contributor
zsh templates/openclaw-contributor/tests/occ-v2.test.sh templates/openclaw-contributor
zsh templates/job-application-coordinator/tests/jac-v3-steps.test.sh templates/job-application-coordinator
```

The migration tests also take an older package folder. Get one from a tag:

```sh
mkdir -p /tmp/jac-0.2.0
git archive job-application-coordinator@0.2.0 templates/job-application-coordinator | tar -x -C /tmp/jac-0.2.0
zsh templates/job-application-coordinator/tests/jac-migrate-v3.test.sh templates/job-application-coordinator /tmp/jac-0.2.0/templates/job-application-coordinator
```

`jac-package.test.sh` checks every file in the package folder, so give it the package files alone, without `tests/` and `scripts/`:

```sh
J=templates/job-application-coordinator
mkdir -p /tmp/jac-pkg
git archive HEAD $J ":(exclude)$J/tests" ":(exclude)$J/scripts" | tar -x -C /tmp/jac-pkg
zsh $J/tests/jac-package.test.sh /tmp/jac-pkg/$J
```

The gate scripts in `scripts/` expect an OpenClaw build and the ClawHub CLI at the paths named at their top. Read a script before you run it.

## Add a Template

1. Make a folder `templates/<name>/` with the package source at its root. `openclaw templates validate .` must pass.
2. Put tests in `tests/` and gate scripts in `scripts/`.
3. Add a row to the table above.
4. Commit each release as `<name> <version>: <one line from its CHANGELOG>` and tag it `<name>@<version>`.

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
