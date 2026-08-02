# Security policy

## Reporting a vulnerability

Please **do not open a public issue** for a security problem.

Report it privately through GitHub's [Security Advisories](https://github.com/menuella/food-safety/security/advisories/new),
or by email to **hello@menuella.com** with `security` in the subject.

We aim to acknowledge within **3 working days** and to publish a fix or a
mitigation within **30 days**, crediting you unless you prefer otherwise.

## Scope

This package ships **data, JSON Schemas, SVG icons and a dependency-free entry
point**. It executes nothing at install time and makes no network calls, so the
usual supply-chain surface is small. Things we do want to hear about:

- A tampered or malformed file that could crash or mislead a consumer
- A vulnerability in the release pipeline or published artefacts
- Anything in `icons/` that a browser could treat as active content

## Data corrections are not security issues

**An incorrect allergen or declaration is a data bug, and it matters — but
please report it in the open** so others can see it and weigh in. Use the
[data correction issue template](https://github.com/menuella/food-safety/issues/new?template=data-correction.yml).

If you believe an error is actively causing harm — a missing allergen on a live
menu, say — mark the issue urgent and email as well, and we will prioritise it.

## Supported versions

The latest published version is supported. This dataset is pre-1.0; fixes land
on the newest release rather than being backported.
