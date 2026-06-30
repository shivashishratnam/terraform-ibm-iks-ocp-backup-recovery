## Description

<!-- Describe the change and why it is needed. Link to the related issue if applicable (e.g., "Fixes #123"). -->

## Type of change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that changes existing behaviour — requires major version bump)
- [ ] Documentation update
- [ ] Refactor / code quality improvement

## Checklist

- [ ] `terraform fmt` has been run — all `.tf` files are properly formatted
- [ ] All new variables have `description` and `type`; all new outputs have `description`
- [ ] New optional variables have defaults that preserve existing behaviour
- [ ] Breaking changes are clearly documented in this PR and will be released as a major version
- [ ] `ignore_changes` blocks (if added) include a comment explaining why
- [ ] Shell scripts quote all variable expansions
- [ ] Tests in `tests/` cover the change (new test added or existing test updated)
- [ ] `pre-commit run --all-files` passes locally
- [ ] README and relevant docs are updated

## Testing

<!-- Describe how this change was tested. If tests were added, name them. -->

## Notes for reviewers

<!-- Anything the reviewer should know: trade-offs made, alternatives considered, follow-up work needed. -->
