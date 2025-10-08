---
allowed-tools: Bash, Read, Write, LS
---

# Issue Close

Mark an issue as complete and close it on GitLab.

## Usage
```
/pm:issue-close <issue_number> [completion_notes]
```

## Instructions

### 1. Find Local Task File

First check if `.claude/epics/*/$ARGUMENTS.md` exists (new naming).
If not found, search for task file with `gitlab:.*issues/$ARGUMENTS` in frontmatter (old naming).
If not found: "❌ No local task for issue #$ARGUMENTS"

### 2. Update Local Status

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Update task file frontmatter:
```yaml
status: closed
updated: {current_datetime}
```

### 3. Update Progress File

If progress file exists at `.claude/epics/{epic}/updates/$ARGUMENTS/progress.md`:
- Set completion: 100%
- Add completion note with timestamp
- Update last_sync with current datetime

### 4. Close on GitLab

Add completion comment and close:
```bash
# Add final comment
glab issue note $ARGUMENTS --message "$(cat <<'EOF'
✅ Task completed

$ARGUMENTS

---
Closed at: {timestamp}
EOF
)"

# Close the issue
glab issue close $ARGUMENTS
```

### 5. Update Epic Task List on GitLab

Check the task checkbox in the epic issue:

```bash
# Get epic name from local task file path
epic_name={extract_from_path}

# Get epic issue iid from epic.md
epic_iid=$(grep 'gitlab:' .claude/epics/$epic_name/epic.md | grep -oE '[0-9]+$')

if [ ! -z "$epic_iid" ]; then
  # Get current epic body
  glab issue view $epic_iid --output json | jq -r '.description' > /tmp/epic-body.md

  # Check off this task
  sed -i "s/- \[ \] #$ARGUMENTS/- [x] #$ARGUMENTS/" /tmp/epic-body.md

  # Update epic issue
  glab issue update $epic_iid --description "$(cat /tmp/epic-body.md)"

  echo "✓ Updated epic progress on GitLab"
fi
```

### 6. Update Epic Progress

- Count total tasks in epic
- Count closed tasks
- Calculate new progress percentage
- Update epic.md frontmatter progress field

### 7. Output

```
✅ Closed issue #$ARGUMENTS
  Local: Task marked complete
  GitLab: Issue closed & epic updated
  Epic progress: {new_progress}% ({closed}/{total} tasks complete)

Next: Run /pm:next for next priority task
```

## Important Notes

Follow `/rules/frontmatter-operations.md` for updates.
Follow `/rules/gitlab-operations.md` for GitLab commands.
Always sync local state before GitLab.