# GitLab Operations Rule

Standard patterns for GitLab CLI operations across all commands.

## CRITICAL: Repository Protection

**Before ANY GitLab operation that creates/modifies issues or merge requests:**

```bash
# Check if remote origin is the CCPM template repository
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$remote_url" == *"automazeio/ccpm-gitlab"* ]] || [[ "$remote_url" == *"automazeio/ccpm"* ]]; then
  echo "❌ ERROR: You're trying to sync with the CCPM template repository!"
  echo ""
  echo "This repository is a template for others to use."
  echo "You should NOT create issues or MRs here."
  echo ""
  echo "To fix this:"
  echo "1. Fork this repository to your own GitLab account"
  echo "2. Update your remote origin:"
  echo "   git remote set-url origin https://gitlab.com/YOUR_USERNAME/YOUR_REPO.git"
  echo ""
  echo "Or if this is a new project:"
  echo "1. Create a new repository on GitLab"
  echo "2. Update your remote origin:"
  echo "   git remote set-url origin https://gitlab.com/YOUR_USERNAME/YOUR_REPO.git"
  echo ""
  echo "Current remote: $remote_url"
  exit 1
fi
```

This check MUST be performed in ALL commands that:
- Create issues (`glab issue create`)
- Edit issues (`glab issue update`)
- Comment on issues (`glab issue note`)
- Create MRs (`glab mr create`)
- Any other operation that modifies the GitLab repository

## Authentication

**Don't pre-check authentication.** Just run the command and handle failure:

```bash
glab {command} || echo "❌ GitLab CLI failed. Run: glab auth login"
```

## Common Operations

### Get Issue Details
```bash
glab issue view {iid} --output json
```

### Create Issue
```bash
# Always specify repo to avoid defaulting to wrong repository
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
REPO=$(echo "$remote_url" | sed 's|.*gitlab.com[:/]||' | sed 's|\.git$||')
[ -z "$REPO" ] && REPO="user/repo"

# Create issue and get IID
issue_iid=$(glab issue create \
  --repo "$REPO" \
  --title "{title}" \
  --description "$(cat {file})" \
  --label "{labels}" \
  --output json | jq -r '.iid')
```

**Important Notes:**
- Use `--description "$(cat file)"` instead of `--body-file` (not supported)
- GitLab returns `iid` (internal ID), not `number`
- Use `jq` to parse JSON output

### Update Issue
```bash
# ALWAYS check remote origin first!
glab issue update {iid} --add-label "{label}" --assignee @me
```

### Add Comment (Note)
```bash
# ALWAYS check remote origin first!
glab issue note {iid} --message "$(cat {file})"
```

**Important Notes:**
- Use `note` not `comment`
- Use `--message` not `--body`
- File content must be passed via `$(cat file)`

### Link Issues (Parent/Child)

GitLab has **native issue linking** - no extension needed!

```bash
# Link during issue creation
glab issue create \
  --title "Task" \
  --description "$(cat task.md)" \
  --linked-issues {epic_iid} \
  --link-type "relates_to" \
  --output json | jq -r '.iid'

# Link existing issues
glab issue update {task_iid} --link-issue {epic_iid} --link-type "relates_to"
```

**Link Types:**
- `relates_to` - General relationship (use for epic-task)
- `blocks` - This issue blocks another
- `is_blocked_by` - This issue is blocked by another

### Close/Reopen Issue
```bash
# Simple commands
glab issue close {iid}
glab issue reopen {iid}
```

### List Issues
```bash
glab issue list --label "epic" --state opened
glab issue list --output json
```

**Important Notes:**
- Use `opened` not `open`
- Use `closed` not `close`

### Get Repository Info
```bash
# Get full repo path with namespace
repo_path=$(glab repo view --output json | jq -r '.path_with_namespace')

# Build issue URL
issue_url="https://gitlab.com/$repo_path/-/issues/$iid"
```

**Important Notes:**
- GitLab URLs use `/-/issues/` format (note the `/-/`)
- Use `.path_with_namespace` from JSON (supports nested groups)

### Create Labels
```bash
# GitLab requires # prefix for colors!
glab label create "epic" --color "#0E8A16" --description "Epic issue"
glab label create "task" --color "#1D76DB" --description "Individual task"
```

## Error Handling

If any glab command fails:
1. Show clear error: "❌ GitLab operation failed: {command}"
2. Suggest fix: "Run: glab auth login" or check issue IID
3. Don't retry automatically

## Important Notes

- **ALWAYS** check remote origin before ANY write operation to GitLab
- Trust that glab CLI is installed and authenticated
- Use `--output json` or `-F json` for structured output
- Parse with `jq` for specific fields
- Keep operations atomic - one glab command per action
- Don't check rate limits preemptively
- GitLab uses `iid` (internal ID) not `number`
- Issue states are "opened" or "closed" (not "open")
- Colors need `#` prefix (e.g., `#0E8A16`)
- URLs use `/-/issues/` format
- Native issue linking replaces gh-sub-issue extension
