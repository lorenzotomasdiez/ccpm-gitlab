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
# Detect GitLab host and repository (supports self-hosted)
remote_url=$(git remote get-url origin 2>/dev/null || echo "")

# Extract GitLab host and repo (POSIX compliant - works in bash, zsh, sh)
if echo "$remote_url" | grep -q '^https://'; then
  # HTTPS: https://gitlab.company.com/owner/repo.git
  GITLAB_HOST=$(echo "$remote_url" | sed 's|^https://||' | sed 's|/.*||')
  REPO=$(echo "$remote_url" | sed 's|^https://[^/]*/||' | sed 's|\.git$||')
elif echo "$remote_url" | grep -q '^http://'; then
  # HTTP: http://gitlab.company.com/owner/repo.git
  GITLAB_HOST=$(echo "$remote_url" | sed 's|^http://||' | sed 's|/.*||')
  REPO=$(echo "$remote_url" | sed 's|^http://[^/]*/||' | sed 's|\.git$||')
elif echo "$remote_url" | grep -q '^git@'; then
  # SSH: git@gitlab.company.com:owner/repo.git
  GITLAB_HOST=$(echo "$remote_url" | sed 's|^git@||' | sed 's|:.*||')
  REPO=$(echo "$remote_url" | sed 's|^git@[^:]*:||' | sed 's|\.git$||')
else
  echo "❌ Could not parse git remote URL: $remote_url"
  exit 1
fi

# Create issue (NOTE: glab issue create does NOT support --output json)
# Must parse text output to extract IID
glab issue create \
  -R "$REPO" \
  -t "{title}" \
  -d "$(cat {file})" \
  -l "{labels}" \
  --no-editor > /tmp/issue-result.txt 2>&1

# Parse output to extract issue IID
# Output format: https://{host}/{owner}/{repo}/-/issues/{iid}
issue_iid=$(grep -o 'issues/[0-9]*' /tmp/issue-result.txt | head -1 | cut -d'/' -f2)

if [ -z "$issue_iid" ]; then
  echo "❌ Failed to create issue"
  cat /tmp/issue-result.txt
  exit 1
fi
```

**Important Notes:**
- **`glab issue create` does NOT support `--output json`** - must parse text output
- Use regex to extract IID from URL in text output
- Support self-hosted GitLab by detecting host dynamically
- Use `--description "$(cat file)"` instead of `--body-file` (not supported)
- GitLab returns `iid` (internal ID), not `number`
- Use `-R` instead of `--repo` (shorter)
- Always use `--no-editor` for non-interactive mode

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

# Build issue URL using detected GitLab host (from git remote)
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if echo "$remote_url" | grep -q '^https://'; then
  GITLAB_HOST=$(echo "$remote_url" | sed 's|^https://||' | sed 's|/.*||')
elif echo "$remote_url" | grep -q '^http://'; then
  GITLAB_HOST=$(echo "$remote_url" | sed 's|^http://||' | sed 's|/.*||')
elif echo "$remote_url" | grep -q '^git@'; then
  GITLAB_HOST=$(echo "$remote_url" | sed 's|^git@||' | sed 's|:.*||')
else
  GITLAB_HOST="gitlab.com"  # fallback
fi

issue_url="https://$GITLAB_HOST/$repo_path/-/issues/$iid"
```

**Important Notes:**
- GitLab URLs use `/-/issues/` format (note the `/-/`)
- Use `.path_with_namespace` from JSON (supports nested groups)
- Always detect GitLab host from git remote (supports self-hosted)
- Don't hardcode `gitlab.com` - use dynamic host detection

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
- **`glab issue create` does NOT support `--output json`** - parse text output instead
- Use `--output json` or `-F json` for `glab issue view` and `glab issue list` (supported)
- Parse with `jq` for specific fields from view/list commands
- Parse text output with `grep -o 'issues/[0-9]*'` for issue create commands
- Keep operations atomic - one glab command per action
- Don't check rate limits preemptively
- GitLab uses `iid` (internal ID) not `number`
- Issue states are "opened" or "closed" (not "open")
- Colors need `#` prefix (e.g., `#0E8A16`)
- URLs use `/-/issues/` format
- Native issue linking replaces gh-sub-issue extension
- **Support self-hosted GitLab** - always detect host from git remote dynamically
- Don't hardcode `gitlab.com` - use bash regex to extract host from remote URL
