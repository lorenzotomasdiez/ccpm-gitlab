---
allowed-tools: Bash, Read, Write, LS
---

# Sync

Full bidirectional sync between local and GitLab.

## Usage
```
/pm:sync [epic_name]
```

If epic_name provided, sync only that epic. Otherwise sync all.

## Instructions

### 1. Pull from GitLab

Get current state of all issues:
```bash
# Get all epic and task issues
glab issue list --label "epic" --per-page 1000 --output json
glab issue list --label "task" --per-page 1000 --output json
```

### 2. Update Local from GitLab

For each GitLab issue:
- Find corresponding local file by issue iid
- Compare states:
  - If GitLab state newer (updatedAt > local updated), update local
  - If GitLab closed but local open, close local
  - If GitLab reopened but local closed, reopen local
- Update frontmatter to match GitLab state

### 3. Push Local to GitLab

For each local task/epic:
- If has GitLab URL but GitLab issue not found, it was deleted - mark local as archived
- If no GitLab URL, create new issue (like epic-sync)
- If local updated > GitLab updatedAt, push changes:
  ```bash
  glab issue update {iid} --description "$(cat {local_file})"
  ```

### 4. Handle Conflicts

If both changed (local and GitLab updated since last sync):
- Show both versions
- Ask user: "Local and GitLab both changed. Keep: (local/gitlab/merge)?"
- Apply user's choice

### 5. Update Sync Timestamps

Update all synced files with last_sync timestamp.

### 6. Output

```
🔄 Sync Complete

Pulled from GitLab:
  Updated: {count} files
  Closed: {count} issues

Pushed to GitLab:
  Updated: {count} issues
  Created: {count} new issues

Conflicts resolved: {count}

Status:
  ✅ All files synced
  {or list any sync failures}
```

## Important Notes

Follow `/rules/gitlab-operations.md` for GitLab commands.
Follow `/rules/frontmatter-operations.md` for local updates.
Always backup before sync in case of issues.