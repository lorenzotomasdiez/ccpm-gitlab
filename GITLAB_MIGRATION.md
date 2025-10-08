# GitLab Migration Guide

Complete documentation for migrating CCPM from GitHub to GitLab.

## Table of Contents

- [Overview](#overview)
- [GitLab CLI Command Reference](#gitlab-cli-command-reference)
- [Key Differences](#key-differences)
- [Migration Tasks](#migration-tasks)
- [File-by-File Changes](#file-by-file-changes)
- [Testing Strategy](#testing-strategy)

## Overview

This document provides a complete mapping of GitHub CLI (`gh`) commands to GitLab CLI (`glab`) commands, and outlines all changes needed to migrate CCPM to GitLab.

### What Changes
- Replace `gh` CLI with `glab` CLI
- Update repository detection (github.com → gitlab.com)
- Replace `gh-sub-issue` extension with GitLab native issue relationships
- Update all command files and scripts

### What Stays the Same
- Local-first workflow (PRD → Epic → Tasks)
- Directory structure (`.claude/`)
- Command interface (`/pm:*`)
- Agent system
- Worktree operations

## GitLab CLI Command Reference

### Installation & Authentication

| GitHub | GitLab |
|--------|--------|
| `gh --version` | `glab --version` |
| `gh auth login` | `glab auth login` |
| `gh auth status` | `glab auth status` |
| `gh auth logout` | `glab auth logout` |

### Repository Operations

| GitHub | GitLab |
|--------|--------|
| `gh repo view` | `glab repo view` |
| `gh repo view --json nameWithOwner -q .nameWithOwner` | `glab repo view --output json \| jq -r '.path_with_namespace'` |
| `git remote get-url origin` (parse github.com) | `git remote get-url origin` (parse gitlab.com) |

### Issue Operations

#### Create Issue

**GitHub:**
```bash
gh issue create \
  --repo "owner/repo" \
  --title "Issue Title" \
  --body-file /tmp/body.md \
  --label "label1,label2" \
  --json number -q .number
```

**GitLab:**
```bash
glab issue create \
  --repo "owner/repo" \
  --title "Issue Title" \
  --description "$(cat /tmp/body.md)" \
  --label "label1,label2" \
  --output json | jq -r '.iid'
```

**Key Differences:**
- `--body-file` → `--description "$(cat file)"` (glab doesn't support file input directly)
- `--json number -q .number` → `--output json | jq -r '.iid'`
- GitLab uses `iid` (internal ID) not `number`

#### View Issue

**GitHub:**
```bash
gh issue view 123 --json state,title,labels,body
```

**GitLab:**
```bash
glab issue view 123 --output json
```

**Key Differences:**
- GitLab returns all fields by default
- Access with `jq`: `glab issue view 123 -F json | jq -r '.state'`

#### Edit Issue

**GitHub:**
```bash
gh issue edit 123 --add-label "label1"
gh issue edit 123 --title "New Title"
```

**GitLab:**
```bash
glab issue update 123 --add-label "label1"
glab issue update 123 --title "New Title"
```

**Key Differences:**
- `edit` → `update`
- `--add-label` works the same
- `--remove-label` works the same

#### Close/Reopen Issue

**GitHub:**
```bash
gh issue close 123
gh issue reopen 123
```

**GitLab:**
```bash
glab issue close 123
glab issue reopen 123
```

**Key Differences:**
- Same commands! ✅

#### Add Comment/Note

**GitHub:**
```bash
gh issue comment 123 --body "Comment text"
gh issue comment 123 --body-file /tmp/comment.md
```

**GitLab:**
```bash
glab issue note 123 --message "Comment text"
glab issue note 123 --message "$(cat /tmp/comment.md)"
```

**Key Differences:**
- `comment` → `note`
- `--body` → `--message`
- `--body-file` → `--message "$(cat file)"`

#### List Issues

**GitHub:**
```bash
gh issue list --label "epic" --state open
gh issue list --json number,title,state
```

**GitLab:**
```bash
glab issue list --label "epic" --state opened
glab issue list --output json
```

**Key Differences:**
- `--state open` → `--state opened`
- `--state closed` → `--state closed`

### Issue Relationships (Parent/Child)

This is where GitLab **shines** - native support without extensions!

**GitHub (requires gh-sub-issue extension):**
```bash
gh extension install yahsan2/gh-sub-issue
gh sub-issue create --parent 123 --title "Task" --body-file task.md
```

**GitLab (native):**
```bash
# Option 1: Link during creation
glab issue create \
  --title "Task" \
  --description "$(cat task.md)" \
  --linked-issues 123 \
  --link-type "relates_to"

# Option 2: Link existing issues
glab issue update 456 --link-issue 123 --link-type "relates_to"
```

**GitLab Link Types:**
- `relates_to` - General relationship (default)
- `blocks` - This issue blocks another
- `is_blocked_by` - This issue is blocked by another

**Best Practice for CCPM:**
Use `relates_to` for epic-task relationships. GitLab will show these in the issue's "Related issues" section.

### Label Operations

**GitHub:**
```bash
gh label create "epic" --color "0E8A16" --description "Epic issue"
gh label list
```

**GitLab:**
```bash
glab label create "epic" --color "#0E8A16" --description "Epic issue"
glab label list
```

**Key Differences:**
- Color must include `#` prefix in GitLab
- Otherwise identical

### JSON Output Parsing

**GitHub:**
```bash
gh issue view 123 --json number,title,state -q .number
```

**GitLab:**
```bash
glab issue view 123 -F json | jq -r '.iid'
```

**Key Differences:**
- `-F json` or `--output json` for JSON format
- No built-in query syntax, use `jq`
- `number` → `iid` (internal ID)
- `state` values: "opened" or "closed" (not "open")

## Key Differences

### 1. Issue IDs

- **GitHub**: Uses `number` (sequential across all issues/PRs)
- **GitLab**: Uses `iid` (internal ID, sequential per project)

```bash
# GitHub
issue_num=$(gh issue create ... --json number -q .number)

# GitLab
issue_iid=$(glab issue create ... --output json | jq -r '.iid')
```

### 2. Issue States

- **GitHub**: `open`, `closed`
- **GitLab**: `opened`, `closed`

### 3. Body/Description

- **GitHub**: `--body`, `--body-file`
- **GitLab**: `--description` (text only, use `"$(cat file)"` for files)

### 4. Parent/Child Relationships

- **GitHub**: Requires `gh-sub-issue` extension, creates actual parent/child
- **GitLab**: Native `--linked-issues` with relationship types

### 5. Repository Format

- **GitHub**: `owner/repo` from URL
- **GitLab**: `owner/repo` or `group/subgroup/repo` (supports nested groups!)

### 6. Remote URL Detection

```bash
# GitHub detection
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$remote_url" == *"github.com"* ]]; then
  REPO=$(echo "$remote_url" | sed 's|.*github.com[:/]||' | sed 's|\.git$||')
fi

# GitLab detection
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$remote_url" == *"gitlab.com"* ]]; then
  REPO=$(echo "$remote_url" | sed 's|.*gitlab.com[:/]||' | sed 's|\.git$||')
fi
```

### 7. Color Codes

- **GitHub**: Hex without `#` prefix (e.g., `0E8A16`)
- **GitLab**: Hex with `#` prefix (e.g., `#0E8A16`)

## Migration Tasks

### Task 1: Update ccpm.config ✅

**File:** `ccpm/ccpm.config`

**Changes:**
```bash
# OLD: GitHub detection
get_github_repo() {
    local remote_url=$(git remote get-url origin 2>/dev/null)
    repo=$(echo "$repo" | sed -E 's#^https://github\.com/##')
    repo=$(echo "$repo" | sed -E 's#^git@github\.com:##')
    # ...
}
export GH_REPO="$GITHUB_REPO"

# NEW: GitLab detection
get_gitlab_repo() {
    local remote_url=$(git remote get-url origin 2>/dev/null)

    if [ -z "$remote_url" ]; then
        echo "Error: No git remote found" >&2
        return 1
    fi

    # Handle HTTPS, SSH, and SCP-style URLs
    local repo="$remote_url"
    # Remove various GitLab URL prefixes
    repo=$(echo "$repo" | sed -E 's#^https://gitlab\.com/##')
    repo=$(echo "$repo" | sed -E 's#^git@gitlab\.com:##')
    repo=$(echo "$repo" | sed -E 's#^ssh://git@gitlab\.com/##')
    repo=$(echo "$repo" | sed -E 's#^ssh://gitlab\.com/##')
    # Remove .git suffix if present
    repo=$(echo "$repo" | sed 's#\.git$##')

    # Validate format (supports nested groups)
    if [[ ! "$repo" =~ ^[^/]+/.+$ ]]; then
        echo "Error: Invalid repository format: $repo" >&2
        return 1
    fi

    echo "$repo"
}

# Allow environment override
if [ -n "$CCPM_GITLAB_REPO" ]; then
    GITLAB_REPO="$CCPM_GITLAB_REPO"
else
    GITLAB_REPO=$(get_gitlab_repo) || exit 1
fi

# Export for glab CLI
export GITLAB_REPO="$GITLAB_REPO"

# Validate repository exists (optional)
if [ "${CCPM_SKIP_REPO_VALIDATION:-false}" != "true" ]; then
    if ! glab repo view "$GITLAB_REPO" >/dev/null 2>&1; then
        echo "Warning: Repository $GITLAB_REPO not accessible. Please ensure:" >&2
        echo "  1. Repository exists on GitLab" >&2
        echo "  2. You have write access" >&2
        echo "  3. You're authenticated with glab CLI (run: glab auth login)" >&2
    fi
fi

# Wrapper function with error handling and logging
glab_issue_create() {
    echo "Creating issue in: $GITLAB_REPO" >&2
    glab issue create --repo "$GITLAB_REPO" "$@"
}

# Export functions for use in other scripts
export -f get_gitlab_repo
export -f glab_issue_create
```

**Rename:** `ccpm.config` → `ccpm.gitlab.config` (or keep same name)

### Task 2: Update gitlab-operations.md ✅

**File:** `ccpm/rules/github-operations.md` → `ccpm/rules/gitlab-operations.md`

**New Content:**
```markdown
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

# Create issue
issue_iid=$(glab issue create \
  --repo "$REPO" \
  --title "{title}" \
  --description "$(cat {file})" \
  --label "{labels}" \
  --output json | jq -r '.iid')
```

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

### Link Issues (Parent/Child)
```bash
# Link task to epic
glab issue update {task_iid} --link-issue {epic_iid} --link-type "relates_to"

# Or during creation
glab issue create \
  --title "Task" \
  --description "$(cat task.md)" \
  --linked-issues {epic_iid} \
  --link-type "relates_to"
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
```

### Task 3: Update init.sh ✅

**File:** `ccpm/scripts/pm/init.sh`

**Changes:**

Replace all `gh` references with `glab`:

```bash
# Check glab CLI (line 28-43)
if command -v glab &> /dev/null; then
  echo "  ✅ GitLab CLI (glab) installed"
else
  echo "  ❌ GitLab CLI (glab) not found"
  echo ""
  echo "  Installing glab..."
  if command -v brew &> /dev/null; then
    brew install glab
  elif command -v apt-get &> /dev/null; then
    # Add GitLab package repository
    curl -s https://packages.gitlab.com/install/repositories/gitlab/glab/script.deb.sh | sudo bash
    sudo apt-get install glab
  else
    echo "  Please install GitLab CLI manually: https://gitlab.com/gitlab-org/cli"
    exit 1
  fi
fi

# Check glab auth status (line 45-54)
echo ""
echo "🔐 Checking GitLab authentication..."
if glab auth status &> /dev/null; then
  echo "  ✅ GitLab authenticated"
else
  echo "  ⚠️ GitLab not authenticated"
  echo "  Running: glab auth login"
  glab auth login
fi

# REMOVE gh-sub-issue extension section (line 56-64)
# GitLab has native issue linking, no extension needed!

# Update remote check (line 96-106)
if [[ "$remote_url" == *"automazeio/ccpm"* ]] || [[ "$remote_url" == *"automazeio/ccpm-gitlab"* ]]; then
  echo ""
  echo "  ⚠️ WARNING: Your remote origin points to the CCPM template repository!"
  echo "  This means any issues you create will go to the template repo, not your project."
  echo ""
  echo "  To fix this:"
  echo "  1. Fork the repository or create your own on GitLab"
  echo "  2. Update your remote:"
  echo "     git remote set-url origin https://gitlab.com/YOUR_USERNAME/YOUR_REPO.git"
  echo ""
else
  # Create GitLab labels if this is a GitLab repository
  if glab repo view &> /dev/null; then
    echo ""
    echo "🏷️ Creating GitLab labels..."

    # Create base labels with improved error handling
    epic_created=false
    task_created=false

    # Note: GitLab requires # prefix for colors
    if glab label create "epic" --color "#0E8A16" --description "Epic issue containing multiple related tasks" 2>/dev/null; then
      epic_created=true
    elif glab label list 2>/dev/null | grep -q "^epic"; then
      epic_created=true
    fi

    if glab label create "task" --color "#1D76DB" --description "Individual task within an epic" 2>/dev/null; then
      task_created=true
    elif glab label list 2>/dev/null | grep -q "^task"; then
      task_created=true
    fi

    # Report results
    if $epic_created && $task_created; then
      echo "  ✅ GitLab labels created (epic, task)"
    elif $epic_created || $task_created; then
      echo "  ⚠️ Some GitLab labels created (epic: $epic_created, task: $task_created)"
    else
      echo "  ❌ Could not create GitLab labels (check repository permissions)"
    fi
  else
    echo "  ℹ️ Not a GitLab repository - skipping label creation"
  fi
fi

# Update summary (line 180-183)
echo "📊 System Status:"
glab --version | head -1
echo "  Auth: $(glab auth status 2>&1 | grep -o 'Logged in to [^ ]*' || echo 'Not authenticated')"
```

### Task 4: Update epic-sync.md ✅

**File:** `ccpm/commands/pm/epic-sync.md`

**Major Changes:**

1. **Update repository protection check** (line 32-54):
```bash
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$remote_url" == *"automazeio/ccpm"* ]] || [[ "$remote_url" == *"automazeio/ccpm-gitlab"* ]]; then
  echo "❌ ERROR: You're trying to sync with the CCPM template repository!"
  # ... (same error message, update URLs to gitlab.com)
  exit 1
fi
```

2. **Update repository detection** (line 58-65):
```bash
# Get the current repository from git remote
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
REPO=$(echo "$remote_url" | sed 's|.*gitlab.com[:/]||' | sed 's|\.git$||')
[ -z "$REPO" ] && REPO="user/repo"
echo "Creating issues in repository: $REPO"
```

3. **Update epic issue creation** (line 121-127):
```bash
# Create epic issue with labels
epic_iid=$(glab issue create \
  --repo "$REPO" \
  --title "Epic: $ARGUMENTS" \
  --description "$(cat /tmp/epic-body.md)" \
  --label "epic,epic:$ARGUMENTS,$epic_type" \
  --output json | jq -r '.iid')
```

4. **Remove gh-sub-issue check** (line 133-141):
```bash
# GitLab has native issue linking, always use it!
use_native_links=true
```

5. **Update task creation (sequential)** (line 153-182):
```bash
for task_file in .claude/epics/$ARGUMENTS/[0-9][0-9][0-9].md; do
  [ -f "$task_file" ] || continue

  # Extract task name from frontmatter
  task_name=$(grep '^name:' "$task_file" | sed 's/^name: *//')

  # Strip frontmatter from task content
  sed '1,/^---$/d; 1,/^---$/d' "$task_file" > /tmp/task-body.md

  # Create task issue linked to epic
  task_iid=$(glab issue create \
    --repo "$REPO" \
    --title "$task_name" \
    --description "$(cat /tmp/task-body.md)" \
    --label "task,epic:$ARGUMENTS" \
    --linked-issues "$epic_iid" \
    --link-type "relates_to" \
    --output json | jq -r '.iid')

  # Record mapping for renaming
  echo "$task_file:$task_iid" >> /tmp/task-mapping.txt
done
```

6. **Update task creation (parallel)** (line 196-234):
```bash
# Batch tasks for parallel processing
# Each agent must use glab with native linking
Task:
  description: "Create GitLab issues batch {X}"
  subagent_type: "general-purpose"
  prompt: |
    Create GitLab issues for tasks in epic $ARGUMENTS
    Parent epic issue: #$epic_iid

    Tasks to process:
    - {list of 3-4 task files}

    For each task file:
    1. Extract task name from frontmatter
    2. Strip frontmatter using: sed '1,/^---$/d; 1,/^---$/d'
    3. Create issue with native linking:
       glab issue create --repo "$REPO" --title "$task_name" \
         --description "$(cat /tmp/task-body.md)" \
         --label "task,epic:$ARGUMENTS" \
         --linked-issues $epic_iid \
         --link-type "relates_to" \
         --output json | jq -r '.iid'
    4. Record: task_file:issue_iid

    IMPORTANT: Always include --label and --linked-issues parameters

    Return mapping of files to issue IIDs.
```

7. **Update file renaming and references** (line 262-293):
```bash
# Update github field to gitlab field in frontmatter
glab repo view --output json > /tmp/repo-info.json
repo_path=$(jq -r '.path_with_namespace' /tmp/repo-info.json)
gitlab_url="https://gitlab.com/$repo_path/-/issues/$task_iid"

# Update frontmatter with GitLab URL and current timestamp
current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Use sed to update the gitlab and updated fields
sed -i.bak "/^gitlab:/c\gitlab: $gitlab_url" "$new_name"
sed -i.bak "/^updated:/c\updated: $current_date" "$new_name"
rm "${new_name}.bak"
```

8. **Remove fallback task list section** (line 299-319):
```bash
# Not needed! GitLab shows linked issues automatically in the UI
```

9. **Update epic file updates** (line 327-335):
```bash
# Get repo info
repo_path=$(glab repo view --output json | jq -r '.path_with_namespace')
epic_url="https://gitlab.com/$repo_path/-/issues/$epic_iid"
current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Update epic frontmatter
sed -i.bak "/^gitlab:/c\gitlab: $epic_url" .claude/epics/$ARGUMENTS/epic.md
sed -i.bak "/^updated:/c\updated: $current_date" .claude/epics/$ARGUMENTS/epic.md
rm .claude/epics/$ARGUMENTS/epic.md.bak
```

10. **Update mapping file** (line 399-420):
```bash
cat > .claude/epics/$ARGUMENTS/gitlab-mapping.md << EOF
# GitLab Issue Mapping

Epic: #${epic_iid} - https://gitlab.com/${repo_path}/-/issues/${epic_iid}

Tasks:
EOF

# Add each task mapping
for task_file in .claude/epics/$ARGUMENTS/[0-9]*.md; do
  [ -f "$task_file" ] || continue

  issue_iid=$(basename "$task_file" .md)
  task_name=$(grep '^name:' "$task_file" | sed 's/^name: *//')

  echo "- #${issue_iid}: ${task_name} - https://gitlab.com/${repo_path}/-/issues/${issue_iid}" >> .claude/epics/$ARGUMENTS/gitlab-mapping.md
done

# Add sync timestamp
echo "" >> .claude/epics/$ARGUMENTS/gitlab-mapping.md
echo "Synced: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> .claude/epics/$ARGUMENTS/gitlab-mapping.md
```

11. **Update output** (line 440-452):
```bash
✅ Synced to GitLab
  - Epic: #{epic_iid} - {epic_title}
  - Tasks: {count} issues created and linked
  - Labels applied: epic, task, epic:{name}
  - Files renamed: 001.md → {issue_iid}.md
  - References updated: depends_on/conflicts_with now use issue IIDs
  - Worktree: ../epic-$ARGUMENTS

Next steps:
  - Start parallel execution: /pm:epic-start $ARGUMENTS
  - Or work on single issue: /pm:issue-start {issue_iid}
  - View epic: https://gitlab.com/{owner}/{repo}/-/issues/{epic_iid}
```

### Task 5: Update issue-sync.md ✅

**File:** `ccpm/commands/pm/issue-sync.md`

**Major Changes:**

1. **Update repository protection** (line 24-33):
```bash
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$remote_url" == *"automazeio/ccpm"* ]] || [[ "$remote_url" == *"automazeio/ccpm-gitlab"* ]]; then
  echo "❌ ERROR: Cannot sync to CCPM template repository!"
  echo "Update your remote: git remote set-url origin https://gitlab.com/YOUR_USERNAME/YOUR_REPO.git"
  exit 1
fi
```

2. **Update authentication check** (line 35-37):
```bash
# Run: `glab auth status`
# If not authenticated, tell user: "❌ GitLab CLI not authenticated. Run: glab auth login"
```

3. **Update issue validation** (line 39-42):
```bash
# Run: `glab issue view $ARGUMENTS --output json`
# Check state field from JSON response
```

4. **Update comment posting** (line 127-130):
```bash
# Use GitLab CLI to add note:
glab issue note $ARGUMENTS --message "$(cat {temp_comment_file})"
```

5. **Update frontmatter field names** (line 136-144):
```bash
---
name: [Task Title]
status: open
created: [preserve existing date]
updated: [Use REAL datetime from command above]
gitlab: https://gitlab.com/{org}/{repo}/-/issues/$ARGUMENTS
---
```

6. **Update completion comment** (line 209):
```bash
# Post completion note using glab issue note
```

7. **Update output** (line 226):
```bash
🔗 View update: glab issue view $ARGUMENTS --comments
```

### Task 6: Update All Other Command Files

**Files to update:**
- `ccpm/commands/pm/issue-show.md`
- `ccpm/commands/pm/issue-status.md`
- `ccpm/commands/pm/issue-edit.md`
- `ccpm/commands/pm/issue-close.md`
- `ccpm/commands/pm/issue-reopen.md`
- `ccpm/commands/pm/issue-analyze.md`
- `ccpm/commands/pm/import.md`
- `ccpm/commands/pm/epic-refresh.md`
- `ccpm/commands/pm/epic-merge.md`
- `ccpm/commands/pm/epic-edit.md`
- `ccpm/commands/pm/epic-close.md`
- `ccpm/commands/pm/epic-start.md`
- `ccpm/commands/pm/epic-start-worktree.md`
- `ccpm/commands/pm/epic-oneshot.md`
- `ccpm/commands/pm/sync.md`
- `ccpm/commands/pm/prd-parse.md`

**Pattern for each file:**

1. Replace `gh` with `glab`
2. Replace `--body-file X` with `--description "$(cat X)"`
3. Replace `--json field -q .field` with `--output json | jq -r '.field'`
4. Replace `number` with `iid`
5. Replace `github:` frontmatter field with `gitlab:`
6. Replace `github.com` URLs with `gitlab.com/-/issues/`
7. Replace issue state checks: `open` → `opened`
8. Replace `gh issue comment` with `glab issue note`
9. Replace `gh issue edit` with `glab issue update`

### Task 7: Update Documentation Files

**Files to update:**

1. **README.md**
   - Replace all references to GitHub with GitLab
   - Update installation URLs
   - Update issue URLs in examples
   - Change "GitHub Issues" to "GitLab Issues"
   - Update authentication steps
   - Remove gh-sub-issue extension references

2. **COMMANDS.md**
   - Update command descriptions
   - Change GitHub references to GitLab

3. **AGENTS.md**
   - No changes needed (platform-agnostic)

4. **CLAUDE.md**
   - Update GitLab operations section
   - Update URLs to gitlab.com
   - Update CLI commands

5. **LOCAL_MODE.md**
   - Update sync command references
   - Change "GitHub-Only Commands" to "GitLab-Only Commands"

## Testing Strategy

### Phase 1: Local Testing (No GitLab)
1. Test PRD creation: `/pm:prd-new test-feature`
2. Test epic parsing: `/pm:prd-parse test-feature`
3. Test decomposition: `/pm:epic-decompose test-feature`
4. Verify all files created correctly
5. Check frontmatter structure

### Phase 2: GitLab Authentication
1. Install glab CLI
2. Run `/pm:init`
3. Verify authentication: `glab auth status`
4. Create test labels manually
5. Test repository detection

### Phase 3: Issue Creation
1. Create test GitLab repository
2. Update git remote to test repo
3. Run `/pm:epic-sync test-feature`
4. Verify epic issue created
5. Verify task issues created
6. Check issue linking in GitLab UI
7. Verify labels applied

### Phase 4: Issue Updates
1. Run `/pm:issue-start {iid}`
2. Make local updates
3. Run `/pm:issue-sync {iid}`
4. Verify note posted to GitLab
5. Check frontmatter updates

### Phase 5: Full Workflow
1. Create new PRD
2. Parse to epic
3. Decompose to tasks
4. Sync to GitLab
5. Start work on issue
6. Sync progress
7. Close issue
8. Verify epic progress updates

### Phase 6: Edge Cases
1. Test with nested GitLab groups
2. Test with long descriptions
3. Test with special characters in titles
4. Test rate limiting behavior
5. Test error handling (wrong IID, auth failure, etc.)

## Quick Reference

### Command Translations

| Operation | GitHub | GitLab |
|-----------|--------|--------|
| Install CLI | `brew install gh` | `brew install glab` |
| Auth | `gh auth login` | `glab auth login` |
| Create issue | `gh issue create --body-file X` | `glab issue create --description "$(cat X)"` |
| View issue | `gh issue view 123` | `glab issue view 123` |
| Edit issue | `gh issue edit 123` | `glab issue update 123` |
| Comment | `gh issue comment 123` | `glab issue note 123` |
| Link issues | `gh sub-issue create --parent X` | `glab issue create --linked-issues X` |
| Get JSON | `--json field -q .field` | `--output json \| jq -r '.field'` |
| Issue ID field | `.number` | `.iid` |
| Issue state | `open`/`closed` | `opened`/`closed` |

### Frontmatter Changes

```yaml
# Before (GitHub)
---
github: https://github.com/owner/repo/issues/123
---

# After (GitLab)
---
gitlab: https://gitlab.com/owner/repo/-/issues/123
---
```

### URL Structure

```bash
# GitHub
https://github.com/{owner}/{repo}/issues/{number}

# GitLab
https://gitlab.com/{owner}/{repo}/-/issues/{iid}
```

Note the `/-/` segment in GitLab URLs!

## Implementation Checklist

- [ ] Update `ccpm/ccpm.config` → `ccpm/ccpm.gitlab.config`
- [ ] Create `ccpm/rules/gitlab-operations.md`
- [ ] Update `ccpm/scripts/pm/init.sh`
- [ ] Update `ccpm/commands/pm/epic-sync.md`
- [ ] Update `ccpm/commands/pm/issue-sync.md`
- [ ] Update `ccpm/commands/pm/issue-show.md`
- [ ] Update `ccpm/commands/pm/issue-status.md`
- [ ] Update `ccpm/commands/pm/issue-edit.md`
- [ ] Update `ccpm/commands/pm/issue-close.md`
- [ ] Update `ccpm/commands/pm/issue-reopen.md`
- [ ] Update `ccpm/commands/pm/issue-analyze.md`
- [ ] Update `ccpm/commands/pm/import.md`
- [ ] Update `ccpm/commands/pm/epic-refresh.md`
- [ ] Update `ccpm/commands/pm/epic-merge.md`
- [ ] Update `ccpm/commands/pm/epic-edit.md`
- [ ] Update `ccpm/commands/pm/epic-close.md`
- [ ] Update `ccpm/commands/pm/epic-start.md`
- [ ] Update `ccpm/commands/pm/epic-start-worktree.md`
- [ ] Update `ccpm/commands/pm/epic-oneshot.md`
- [ ] Update `ccpm/commands/pm/sync.md`
- [ ] Update `ccpm/commands/pm/prd-parse.md`
- [ ] Update `README.md`
- [ ] Update `COMMANDS.md`
- [ ] Update `CLAUDE.md`
- [ ] Update `LOCAL_MODE.md`
- [ ] Test local-only workflow
- [ ] Test GitLab authentication
- [ ] Test issue creation
- [ ] Test issue linking
- [ ] Test issue updates
- [ ] Test full workflow
- [ ] Test edge cases

## Notes

- GitLab's native issue relationships are superior to GitHub's extension-based approach
- GitLab supports nested groups (e.g., `group/subgroup/repo`), GitHub doesn't
- GitLab's `iid` is per-project, GitHub's `number` is global
- GitLab CLI requires `jq` for JSON parsing (GitHub CLI has built-in query)
- Color codes need `#` prefix in GitLab
- GitLab uses "opened" state, GitHub uses "open"
