---
description: Workflow for implementing new features - branch, commit, PR, merge
---

# Feature Development Workflow

## When user requests a new feature:

### 1. Create Feature Branch

Use descriptive branch names with prefixes:
```bash
# For new features
git checkout -b feature/[feature-name]

# For bug fixes
git checkout -b fix/[bug-description]

# For development/experimental
git checkout -b develop/[experiment-name]

# For documentation
git checkout -b docs/[doc-update]
```

### 2. Implementation

1. Create implementation plan first (if complex)
2. Get user approval on the plan
3. Implement the feature
4. Run tests: `flutter test`
5. Check for lint issues: `flutter analyze`

### 3. Before Commit - MUST ASK USER

**IMPORTANT**: Do NOT auto-generate commit messages. Always ask user first:

```
"Implementation complete. Does this match what you requested?
If yes, would you like to commit? Here's a suggested commit message:

[commit message suggestion]

Use this or would you like to change it?"
```

Wait for user response before committing.

#### Conventional Commit Types

Use these prefixes for commit messages:
| Type | Description |
|------|-------------|
| `feat:` | New feature |
| `fix:` | Bug fix |
| `docs:` | Documentation only |
| `refactor:` | Code refactoring (no feature change) |
| `test:` | Adding/updating tests |
| `chore:` | Maintenance tasks (deps, config) |
| `style:` | Formatting, whitespace |
| `perf:` | Performance improvements |

Example:
```
feat: Add Android 14+ exact alarm permission handling

- Add canScheduleExactAlarms() method
- Add openExactAlarmSettings() method
- Update README with permission guide
```

### 4. After Commit - Ask About Push
```
"Committed. Would you like to push to remote?"
```

Wait for user response.

### 5. Merge to Main - Ask User
```
"Feature branch pushed. Would you like to merge to main now?"
```

If user agrees:
```bash
git checkout main
git pull origin main  # Ensure up-to-date
git merge feature/[feature-name] --no-ff -m "Merge branch 'feature/[name]' - [description]"
git push origin main
```

### 6. Version Bump (if releasing)

Follow Semantic Versioning:
- **MAJOR** (1.0.0 → 2.0.0): Breaking changes
- **MINOR** (1.0.0 → 1.1.0): New features, backward compatible
- **PATCH** (1.0.0 → 1.0.1): Bug fixes

Update:
1. `pubspec.yaml` version
2. `CHANGELOG.md` with release date
3. Commit: `chore: Release vX.Y.Z`

### 7. Publish (if package) - Ask User
```
"Merged to main and version bumped. Would you like to publish to pub.dev?"
```

If user agrees:
```bash
dart pub publish --force
```

---

## Rules

1. **DO NOT** commit/push without user confirmation
2. **DO NOT** merge without user confirmation  
3. **DO NOT** publish without user confirmation
4. Always suggest commit messages, but wait for approval
5. Only proceed when user explicitly says "yes" / "ok" / "go" / "do it"
6. Always run tests before suggesting commit
7. Delete feature branch after successful merge (optional, ask user)

## Quick Reference

```
User Request
    ↓
Create Branch (feature/*, fix/*, docs/*)
    ↓
Implement + Test
    ↓
ASK: "Ready to commit? [suggested message]"
    ↓ (user confirms)
Commit
    ↓
ASK: "Push to remote?"
    ↓ (user confirms)
Push
    ↓
ASK: "Merge to main?"
    ↓ (user confirms)
Merge + Push main
    ↓
ASK: "Publish to pub.dev?"
    ↓ (user confirms)
Publish
```
