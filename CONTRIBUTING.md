# Contributing

Thank you for considering a contribution to this module. This repository is part of the [IBM Terraform Modules](https://github.com/terraform-ibm-modules) organization.

## IBM Contributor License Agreement

All external contributors must sign the IBM Contributor License Agreement (CLA) before a pull request can be merged. The CLA bot will comment on your first pull request with instructions.

If you are an IBM employee contributing as part of your job responsibilities, you do not need to sign the CLA.

## How to contribute

1. **Open an issue first** for significant changes so the maintainers can discuss the approach before you invest time in implementation.
2. **Fork** the repository and create a feature branch from `main`.
3. **Follow the coding standards** documented below.
4. **Add or update tests** in `tests/` for any functional change.
5. **Run pre-commit checks locally** before pushing:
   ```bash
   pip install pre-commit
   pre-commit install
   pre-commit run --all-files
   ```
6. **Open a pull request** against `main` using the PR template. The CI pipeline is triggered by a comment on the PR — a maintainer will run it after reviewing your changes.

## Coding standards

- All Terraform files must be formatted with `terraform fmt`.
- All variables must have `description` and `type`. All outputs must have `description`.
- New optional variables must have safe defaults that preserve existing behaviour.
- Breaking changes (variable removals, type changes, default changes, resource address changes) require a major version bump — discuss in an issue before implementing.
- Shell scripts under `scripts/` must quote all variable expansions to prevent word-splitting.
- Keep `ignore_changes` lifecycle blocks to the minimum necessary, and document each one with a comment explaining why.

## Local development setup

See [Local development setup](https://terraform-ibm-modules.github.io/documentation/#/local-dev-setup) in the IBM Terraform Modules documentation for toolchain prerequisites (Terraform, Go, tflint, terraform-docs, pre-commit).

## Reporting issues

Use [GitHub Issues](https://github.com/terraform-ibm-modules/terraform-ibm-iks-ocp-backup-recovery/issues) to report bugs or request features. See [SUPPORT.md](https://github.com/terraform-ibm-modules/.github/blob/main/.github/SUPPORT.md) for additional support options.
