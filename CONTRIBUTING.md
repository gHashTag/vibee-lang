# Contributing to VIBEE

## Development Workflow

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/my-feature`
3. **Write specification first** — Create `.vibee` file before implementation
4. **Generate code** — Use `vibeec gen` to generate implementation
5. **Test** — Run `zig test` on generated code
6. **Commit** — Follow conventional commits
7. **Submit** pull request

## Specification-First Development

All new features must start with a `.vibee` specification:

```yaml
# specs/my_feature.vibee
name: my_feature
version: "1.0.0"
language: zig
module: my_feature

behaviors:
  - name: feature_behavior
    given: Precondition
    when: Action
    then: Expected result
```

## Code Style

- **Zig**: Follow Zig style guide
- **Specifications**: Use 2-space indentation in YAML
- **Commits**: Use conventional commits (`feat:`, `fix:`, `docs:`)

## Testing

```bash
cd src/vibeec
zig test parser.zig
zig test codegen.zig
```

## Pull Request Guidelines

1. Reference related issue
2. Include specification file
3. Add tests for new behaviors
4. Update documentation if needed

## Questions

Open an issue for questions or discussions.
