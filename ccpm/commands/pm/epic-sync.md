---
allowed-tools: Bash, Read, Write, LS, Task
---

# Epic Sync

Push epic and tasks to GitLab as issues.

## Usage
```
/pm:epic-sync <feature_name>
```

## Quick Check

```bash
# Verify epic exists
test -f .claude/epics/$ARGUMENTS/epic.md || echo "❌ Epic not found. Run: /pm:prd-parse $ARGUMENTS"

# Count task files
ls .claude/epics/$ARGUMENTS/*.md 2>/dev/null | grep -v epic.md | wc -l
```

If no tasks found: "❌ No tasks to sync. Run: /pm:epic-decompose $ARGUMENTS"

## Instructions

### 0. Check Remote Repository

Follow `/rules/gitlab-operations.md` to ensure we're not syncing to the CCPM template:

```bash
# Check if remote origin is the CCPM template repository
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$remote_url" == *"automazeio/ccpm"* ]] || [[ "$remote_url" == *"automazeio/ccpm.git"* ]] || [[ "$remote_url" == *"ccpm-gitlab"* ]]; then
  echo "❌ ERROR: You're trying to sync with the CCPM template repository!"
  echo ""
  echo "This repository (automazeio/ccpm or ccpm-gitlab) is a template for others to use."
  echo "You should NOT create issues or PRs here."
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

### 1. Detect GitLab Host and Repository

Extract both the GitLab host and repository path from git remote:

```bash
# Get remote URL
remote_url=$(git remote get-url origin 2>/dev/null || echo "")

# Extract GitLab host (supports gitlab.com and self-hosted)
if [[ "$remote_url" =~ ^https?://([^/]+)/ ]]; then
  # HTTPS: https://gitlab.company.com/owner/repo.git
  GITLAB_HOST="${BASH_REMATCH[1]}"
  REPO=$(echo "$remote_url" | sed "s|https\?://${GITLAB_HOST}/||" | sed 's|\.git$||')
elif [[ "$remote_url" =~ ^git@([^:]+):(.+)$ ]]; then
  # SSH: git@gitlab.company.com:owner/repo.git
  GITLAB_HOST="${BASH_REMATCH[1]}"
  REPO=$(echo "${BASH_REMATCH[2]}" | sed 's|\.git$||')
else
  echo "❌ Could not parse git remote URL: $remote_url"
  exit 1
fi

echo "Detected GitLab host: $GITLAB_HOST"
echo "Repository path: $REPO"
```

This pattern works for:
- `https://gitlab.com/owner/repo.git`
- `git@gitlab.com:owner/repo.git`
- `https://gitlab.company.com/group/subgroup/repo.git`
- `git@gitlab.company.com:group/subgroup/repo.git`

### 2. Create Epic Issue

Strip frontmatter and prepare GitLab issue body:
```bash
# Extract content without frontmatter
sed '1,/^---$/d; 1,/^---$/d' .claude/epics/$ARGUMENTS/epic.md > /tmp/epic-body-raw.md

# Remove "## Tasks Created" section and replace with Stats
awk '
  /^## Tasks Created/ {
    in_tasks=1
    next
  }
  /^## / && in_tasks {
    in_tasks=0
    # When we hit the next section after Tasks Created, add Stats
    if (total_tasks) {
      print "## Stats"
      print ""
      print "Total tasks: " total_tasks
      print "Parallel tasks: " parallel_tasks " (can be worked on simultaneously)"
      print "Sequential tasks: " sequential_tasks " (have dependencies)"
      if (total_effort) print "Estimated total effort: " total_effort " hours"
      print ""
    }
  }
  /^Total tasks:/ && in_tasks { total_tasks = $3; next }
  /^Parallel tasks:/ && in_tasks { parallel_tasks = $3; next }
  /^Sequential tasks:/ && in_tasks { sequential_tasks = $3; next }
  /^Estimated total effort:/ && in_tasks {
    gsub(/^Estimated total effort: /, "")
    total_effort = $0
    next
  }
  !in_tasks { print }
  END {
    # If we were still in tasks section at EOF, add stats
    if (in_tasks && total_tasks) {
      print "## Stats"
      print ""
      print "Total tasks: " total_tasks
      print "Parallel tasks: " parallel_tasks " (can be worked on simultaneously)"
      print "Sequential tasks: " sequential_tasks " (have dependencies)"
      if (total_effort) print "Estimated total effort: " total_effort
    }
  }
' /tmp/epic-body-raw.md > /tmp/epic-body.md

# Determine epic type (feature vs bug) from content
if grep -qi "bug\|fix\|issue\|problem\|error" /tmp/epic-body.md; then
  epic_type="bug"
else
  epic_type="feature"
fi

# Create epic issue with labels
# NOTE: glab issue create does NOT support --output json
# We must parse the text output to extract the IID
glab issue create \
  -R "$REPO" \
  -t "Epic: $ARGUMENTS" \
  -d "$(cat /tmp/epic-body.md)" \
  -l "epic,epic:$ARGUMENTS,$epic_type" \
  --no-editor > /tmp/epic-result.txt 2>&1

# Parse output to extract issue IID
# Output format: https://{host}/{owner}/{repo}/-/issues/{iid}
epic_iid=$(grep -o 'issues/[0-9]*' /tmp/epic-result.txt | head -1 | cut -d'/' -f2)

if [ -z "$epic_iid" ]; then
  echo "❌ Failed to create epic issue"
  cat /tmp/epic-result.txt
  exit 1
fi

echo "✅ Created epic issue #${epic_iid}"
```

**Key Changes:**
- Removed `--output json` (not supported)
- Parse text output with grep/cut to extract IID
- Use `-R` instead of `--repo` (shorter)
- Use `-t`, `-d`, `-l` instead of long flags

### 3. Create Task Sub-Issues

Count task files:
```bash
task_count=$(ls .claude/epics/$ARGUMENTS/[0-9][0-9][0-9].md 2>/dev/null | wc -l | tr -d ' ')
echo "Creating $task_count task issues..."
```

Create all tasks sequentially (parallel creation causes timeouts):

```bash
# Initialize task mapping file
> /tmp/task-mapping.txt

# Create each task issue
task_num=0
for task_file in .claude/epics/$ARGUMENTS/[0-9][0-9][0-9].md; do
  [ -f "$task_file" ] || continue

  task_num=$((task_num + 1))
  echo "Creating task $task_num/$task_count..."

  # Extract task name from frontmatter
  task_name=$(grep '^name:' "$task_file" | sed 's/^name: *//')

  # Strip frontmatter from task content
  sed '1,/^---$/d; 1,/^---$/d' "$task_file" > /tmp/task-body.md

  # Create sub-issue with labels and link to epic
  glab issue create \
    -R "$REPO" \
    -t "$task_name" \
    -d "$(cat /tmp/task-body.md)" \
    -l "task,epic:$ARGUMENTS" \
    --linked-issues "$epic_iid" \
    --link-type "relates_to" \
    --no-editor > /tmp/task-result.txt 2>&1

  # Parse output to extract task IID
  task_iid=$(grep -o 'issues/[0-9]*' /tmp/task-result.txt | head -1 | cut -d'/' -f2)

  if [ -z "$task_iid" ]; then
    echo "⚠️ Failed to create task: $task_name"
    cat /tmp/task-result.txt
    continue
  fi

  echo "  ✅ Created task #${task_iid}"

  # Record mapping for renaming
  echo "$task_file:$task_iid" >> /tmp/task-mapping.txt
done

# Verify we created some tasks
if [ ! -s /tmp/task-mapping.txt ]; then
  echo "❌ No tasks were created successfully"
  exit 1
fi

echo "✅ Created all task issues"
```

**Key Changes:**
- Removed parallel creation (causes timeouts with large descriptions)
- Sequential is reliable and shows progress
- Skip parallel agent complexity
- Better error handling per task
- Progress feedback for user

### 4. Rename Task Files and Update References

First, build a mapping of old numbers to new issue iids:
```bash
# Create mapping from old task numbers (001, 002, etc.) to new issue iids
> /tmp/id-mapping.txt
while IFS=: read -r task_file task_iid; do
  # Extract old number from filename (e.g., 001 from 001.md)
  old_num=$(basename "$task_file" .md)
  echo "$old_num:$task_iid" >> /tmp/id-mapping.txt
done < /tmp/task-mapping.txt
```

Then rename files and update all references:
```bash
# Process each task file
while IFS=: read -r task_file task_iid; do
  new_name="$(dirname "$task_file")/${task_iid}.md"

  # Read the file content
  content=$(cat "$task_file")

  # Update depends_on and conflicts_with references
  while IFS=: read -r old_num new_num; do
    # Update arrays like [001, 002] to use new issue iids
    content=$(echo "$content" | sed "s/\b$old_num\b/$new_num/g")
  done < /tmp/id-mapping.txt

  # Write updated content to new file
  echo "$content" > "$new_name"

  # Remove old file if different from new
  [ "$task_file" != "$new_name" ] && rm "$task_file"

  # Update gitlab field in frontmatter
  # Build GitLab URL with detected host
  gitlab_url="https://$GITLAB_HOST/$REPO/-/issues/$task_iid"

  # Update frontmatter with GitLab URL and current timestamp
  current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Use sed with backup for macOS compatibility
  sed -i.bak "s|^gitlab:.*|gitlab: $gitlab_url|" "$new_name"
  sed -i.bak "s|^updated:.*|updated: $current_date|" "$new_name"
  rm -f "${new_name}.bak"
done < /tmp/task-mapping.txt
```

**Key Changes:**
- Use `sed -i.bak` for macOS compatibility
- Explicitly remove `.bak` files with `rm -f`
- Build URLs with `$GITLAB_HOST` variable
- Use `s|pattern|replacement|` for URL safety (no escaping slashes)

### 5. Update Epic File

Update the epic file with GitLab URL, timestamp, and real task iids:

#### 5a. Update Frontmatter
```bash
# Build epic URL with detected host
epic_url="https://$GITLAB_HOST/$REPO/-/issues/$epic_iid"
current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Update epic frontmatter with backup for macOS
sed -i.bak "s|^gitlab:.*|gitlab: $epic_url|" .claude/epics/$ARGUMENTS/epic.md
sed -i.bak "s|^updated:.*|updated: $current_date|" .claude/epics/$ARGUMENTS/epic.md
rm -f .claude/epics/$ARGUMENTS/epic.md.bak
```

#### 5b. Update Tasks Created Section
```bash
# Create a temporary file with the updated Tasks Created section
cat > /tmp/tasks-section.md << 'EOF'
## Tasks Created
EOF

# Add each task with its real issue iid
for task_file in .claude/epics/$ARGUMENTS/[0-9]*.md; do
  [ -f "$task_file" ] || continue

  # Get issue iid (filename without .md)
  issue_iid=$(basename "$task_file" .md)

  # Get task name from frontmatter
  task_name=$(grep '^name:' "$task_file" | sed 's/^name: *//')

  # Get parallel status
  parallel=$(grep '^parallel:' "$task_file" | sed 's/^parallel: *//')

  # Add to tasks section
  echo "- [ ] #${issue_iid} - ${task_name} (parallel: ${parallel})" >> /tmp/tasks-section.md
done

# Add summary statistics
total_count=$(ls .claude/epics/$ARGUMENTS/[0-9]*.md 2>/dev/null | wc -l | tr -d ' ')
parallel_count=$(grep -l '^parallel: true' .claude/epics/$ARGUMENTS/[0-9]*.md 2>/dev/null | wc -l | tr -d ' ')
sequential_count=$((total_count - parallel_count))

cat >> /tmp/tasks-section.md << EOF

Total tasks: ${total_count}
Parallel tasks: ${parallel_count}
Sequential tasks: ${sequential_count}
EOF

# Replace the Tasks Created section in epic.md
# First, create a backup
cp .claude/epics/$ARGUMENTS/epic.md .claude/epics/$ARGUMENTS/epic.md.backup

# Use awk to replace the section
awk '
  /^## Tasks Created/ {
    skip=1
    while ((getline line < "/tmp/tasks-section.md") > 0) print line
    close("/tmp/tasks-section.md")
  }
  /^## / && !/^## Tasks Created/ { skip=0 }
  !skip && !/^## Tasks Created/ { print }
' .claude/epics/$ARGUMENTS/epic.md.backup > .claude/epics/$ARGUMENTS/epic.md

# Clean up
rm .claude/epics/$ARGUMENTS/epic.md.backup
rm /tmp/tasks-section.md
```

### 6. Create Mapping File

Create `.claude/epics/$ARGUMENTS/gitlab-mapping.md`:
```bash
# Create mapping file
cat > .claude/epics/$ARGUMENTS/gitlab-mapping.md << EOF
# GitLab Issue Mapping

Epic: #${epic_iid} - https://${GITLAB_HOST}/${REPO}/-/issues/${epic_iid}

Tasks:
EOF

# Add each task mapping
for task_file in .claude/epics/$ARGUMENTS/[0-9]*.md; do
  [ -f "$task_file" ] || continue

  issue_iid=$(basename "$task_file" .md)
  task_name=$(grep '^name:' "$task_file" | sed 's/^name: *//')

  echo "- #${issue_iid}: ${task_name} - https://${GITLAB_HOST}/${REPO}/-/issues/${issue_iid}" >> .claude/epics/$ARGUMENTS/gitlab-mapping.md
done

# Add sync timestamp
echo "" >> .claude/epics/$ARGUMENTS/gitlab-mapping.md
echo "Synced: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> .claude/epics/$ARGUMENTS/gitlab-mapping.md
```

**Key Changes:**
- Use `$GITLAB_HOST` and `$REPO` variables throughout
- Works with any GitLab instance (gitlab.com or self-hosted)

### 7. Create Worktree

Follow `/rules/worktree-operations.md` to create development worktree:

```bash
# Get current branch name
current_branch=$(git branch --show-current)

# Ensure we're on main/master
if [ "$current_branch" != "main" ] && [ "$current_branch" != "master" ]; then
  echo "⚠️ Not on main branch (currently on: $current_branch)"
  echo "Switching to main..."
  git checkout main 2>/dev/null || git checkout master 2>/dev/null || {
    echo "❌ Could not switch to main/master branch"
    exit 1
  }
fi

# Pull latest
git pull origin $(git branch --show-current)

# Create worktree for epic
worktree_path="../epic-$ARGUMENTS"
git worktree add "$worktree_path" -b "epic/$ARGUMENTS"

echo "✅ Created worktree: $worktree_path"
```

### 8. Output

```
✅ Synced to GitLab

Epic: #${epic_iid} - Epic: ${ARGUMENTS}
  URL: https://${GITLAB_HOST}/${REPO}/-/issues/${epic_iid}

Tasks: ${task_count} sub-issues created
  Labels: task, epic:${ARGUMENTS}
  Linked to epic: #${epic_iid}

Files:
  ✅ Renamed: 001.md → ${task_iid}.md
  ✅ Updated: depends_on/conflicts_with arrays with real issue IIDs
  ✅ Updated: Epic and task frontmatter with GitLab URLs

Worktree: ../epic-${ARGUMENTS}

Next steps:
  - Start parallel execution: /pm:epic-start ${ARGUMENTS}
  - Or work on single issue: /pm:issue-start {issue_iid}
  - View epic: https://${GITLAB_HOST}/${REPO}/-/issues/${epic_iid}
```

## Error Handling

Follow `/rules/gitlab-operations.md` for GitLab CLI errors.

**Common Errors:**

1. **Issue creation fails:**
   - Check authentication: `glab auth status`
   - Verify repository access
   - Check description size (max 1MB)
   - Report what succeeded, don't rollback

2. **Timeout errors:**
   - Task descriptions may be too large
   - Network issues
   - Keep partial progress, continue from where it stopped

3. **Rate limiting:**
   - GitLab may throttle rapid issue creation
   - Wait 60 seconds and retry failed tasks
   - Consider creating fewer tasks at once

4. **Self-hosted GitLab:**
   - Ensure `glab auth login` was run for custom host
   - Verify host is reachable
   - Check GitLab version (requires v13+)

## Important Notes

- **Trust GitLab CLI authentication** - Don't pre-check
- **Don't pre-check for duplicates** - Let GitLab handle it
- **Update frontmatter only after successful creation** - Maintain data integrity
- **Keep operations simple and atomic** - One issue at a time
- **Support any GitLab host** - gitlab.com, self-hosted, custom domains
- **Cross-platform sed** - Always use `-i.bak` for macOS compatibility
- **Parse text output** - `glab issue create` doesn't support JSON output
- **Sequential task creation** - More reliable than parallel for large descriptions
