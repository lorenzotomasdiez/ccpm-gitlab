# CCPM Changelog - GitLab Edition

## [2025-10-09] - Critical Fix: epic-sync Command Rewrite

### 🎯 Overview
Complete rewrite of `/pm:epic-sync` command to fix critical GitLab CLI compatibility issues. The original migration from GitHub (`gh`) to GitLab (`glab`) contained multiple syntax errors and assumptions that prevented the command from functioning on self-hosted GitLab instances.

**Update:** Added zsh compatibility by replacing bash-specific regex patterns with POSIX-compliant sed/grep commands.

### 🐛 Critical Issues Fixed

1. **`glab issue create` JSON Output Not Supported** ❌→✅
   - **Problem**: Command used `--output json` flag which doesn't exist for `glab issue create`
   - **Error**: `Unknown flag: --output`
   - **Fix**: Parse text output with `grep -o 'issues/[0-9]*'` to extract issue IID
   - **Impact**: Epic and task creation now works reliably

2. **Positional Arguments Error** ❌→✅
   - **Problem**: `glab` doesn't accept positional arguments after flags
   - **Error**: `Accepts 0 arg(s), received 4/5/7`
   - **Fix**: Use short flags (`-R`, `-t`, `-d`, `-l`) with `--no-editor` for non-interactive mode
   - **Impact**: Commands execute without argument parsing errors

3. **Self-Hosted GitLab Support Broken** ❌→✅
   - **Problem**: Hardcoded `gitlab.com` in repository detection
   - **Error**: Failed to detect custom GitLab hosts like `gitlab.eumediatools.com`
   - **Fix**: Dynamic host detection using bash regex for both HTTPS and SSH remotes
   - **Impact**: Now works with any GitLab instance (gitlab.com, self-hosted, custom domains)

4. **macOS sed Incompatibility** ❌→✅
   - **Problem**: Used `sed -i` without backup extension (Linux syntax)
   - **Error**: sed requires backup file on macOS
   - **Fix**: Consistently use `sed -i.bak` with explicit cleanup (`rm -f *.bak`)
   - **Impact**: Cross-platform compatibility (Linux + macOS)

5. **Task Creation Timeouts** ❌→✅
   - **Problem**: Sequential creation with 2-minute timeout, large descriptions (6-9 hours each)
   - **Error**: `Command timed out after 2m 0s`
   - **Fix**: Removed parallel creation complexity, improved per-task error handling, added progress feedback
   - **Impact**: Reliable task creation with clear progress indicators

6. **URL Building for Self-Hosted** ❌→✅
   - **Problem**: All URLs hardcoded to `https://gitlab.com/...`
   - **Fix**: Build URLs with `$GITLAB_HOST` variable from dynamic detection
   - **Impact**: Correct issue URLs for self-hosted instances

7. **zsh Compatibility** ❌→✅
   - **Problem**: Used bash-specific regex (`[[ =~ ]]` and `${BASH_REMATCH}`)
   - **Error**: `parse error near '('` in zsh shells
   - **Fix**: Replace with POSIX-compliant `grep -q` and `sed` patterns
   - **Impact**: Works in bash, zsh, sh, and other POSIX shells

8. **`--linked-issues` Flag Timeout** ❌→✅
   - **Problem**: Using `--linked-issues` during task creation causes 1m+ timeouts per task
   - **Error**: `Command timed out after 3m 0s` when creating 8 tasks
   - **Fix**: Create tasks without linking, then link all tasks to epic after creation
   - **Impact**: Task creation completes in seconds instead of minutes

9. **Multi-line Loop Parsing** ❌→✅
   - **Problem**: Bash tool flattens multi-line loops causing syntax errors
   - **Error**: `parse error near 'do'`, `unexpected EOF while looking for matching ')'`
   - **Fix**: Use heredoc script files for complex loops, single-line with semicolons for simple loops
   - **Impact**: Commands execute reliably through Bash tool in zsh environment

10. **Incorrect Label Flags** ❌→✅
   - **Problem**: Used `--add-label` and `--labels` (GitHub CLI or incorrect syntax)
   - **Error**: `Unknown flag: --add-label`
   - **Fix**: Use `--label` (singular) to add/replace, `--unlabel` to remove
   - **Impact**: Label operations work correctly without errors

### 🔄 Technical Implementation

#### New Host Detection Pattern (POSIX Compliant)
```bash
# Supports both HTTPS and SSH remotes (works in bash, zsh, sh)
if echo "$remote_url" | grep -q '^https://'; then
  GITLAB_HOST=$(echo "$remote_url" | sed 's|^https://||' | sed 's|/.*||')
  REPO=$(echo "$remote_url" | sed 's|^https://[^/]*/||' | sed 's|\.git$||')
elif echo "$remote_url" | grep -q '^git@'; then
  GITLAB_HOST=$(echo "$remote_url" | sed 's|^git@||' | sed 's|:.*||')
  REPO=$(echo "$remote_url" | sed 's|^git@[^:]*:||' | sed 's|\.git$||')
fi
```

#### New Issue Creation Pattern
```bash
# Create without --output json (not supported)
glab issue create \
  -R "$REPO" \
  -t "Title" \
  -d "$(cat description.md)" \
  -l "label1,label2" \
  --no-editor > /tmp/result.txt 2>&1

# Parse text output for IID
issue_iid=$(grep -o 'issues/[0-9]*' /tmp/result.txt | head -1 | cut -d'/' -f2)
```

#### New sed Pattern (Cross-Platform)
```bash
# macOS-compatible sed with explicit cleanup
sed -i.bak "s|^gitlab:.*|gitlab: $url|" file.md
rm -f file.md.bak
```

#### Task Linking After Creation
```bash
# Create tasks first (fast)
glab issue create -R "$REPO" -t "$title" -d "$desc" -l "task" --no-editor

# Link all tasks to epic AFTER creation (single-line to avoid parsing issues)
while IFS=: read -r task_file task_iid; do glab issue update "$task_iid" --link-issue "$epic_iid" --link-type "relates_to"; done < /tmp/task-mapping.txt
```

#### Multi-line Loop Patterns
```bash
# Complex loops: Use script files
cat > /tmp/script.sh << 'EOFSCRIPT'
#!/bin/bash
for x in 1 2 3; do
  # Complex multi-line logic here
  echo "Processing $x"
done
EOFSCRIPT
bash /tmp/script.sh

# Simple loops: Use single-line with semicolons
for x in 1 2 3; do echo "Item: $x"; done
```

### 📝 Files Modified

1. **`ccpm/commands/pm/epic-sync.md`** - Complete rewrite
   - Lines changed: ~420 (entire file restructured)
   - New host detection (Step 1)
   - Fixed issue creation (Steps 2-3)
   - Fixed URL building (Steps 4-6)
   - Cross-platform sed (throughout)
   - Enhanced error handling

2. **`ccpm/rules/gitlab-operations.md`** - Updated patterns
   - Added self-hosted GitLab support documentation
   - Clarified `--output json` only works for `view` and `list`, not `create`
   - Added text parsing pattern for issue creation
   - Updated "Create Issue" and "Get Repository Info" sections

### 🧪 Testing Coverage

The rewritten command now handles:
- ✅ gitlab.com repositories
- ✅ Self-hosted GitLab instances (e.g., gitlab.company.com)
- ✅ Nested groups (group/subgroup/repo)
- ✅ Both SSH and HTTPS remotes
- ✅ macOS and Linux platforms
- ✅ bash, zsh, sh, and other POSIX shells
- ✅ Small (<5 tasks) and large (≥5 tasks) epics
- ✅ Task reference updates (depends_on arrays)
- ✅ Epic and task frontmatter updates

### 🎓 Root Cause Analysis

**Why This Happened:**
- Direct translation from GitHub CLI (`gh`) to GitLab CLI (`glab`) without API verification
- Assumed feature parity between `gh` and `glab` (especially `--output json`)
- Hardcoded assumptions about GitLab host (gitlab.com only)
- Linux-centric development (sed syntax not tested on macOS)
- Insufficient timeout handling for large API payloads

**Prevention:**
- CLI API documentation review before migration
- Cross-platform testing (Linux + macOS)
- Self-hosted instance testing
- Timeout analysis for large operations

### 🔗 Related Issues

This fix enables the core workflow:
- `/pm:prd-new` → `/pm:prd-parse` → `/pm:epic-decompose` → **`/pm:epic-sync`** → `/pm:issue-start`

Without this fix, users could not:
- Create epic issues in GitLab
- Create task sub-issues
- Link tasks to epics
- Generate issue URLs
- Use self-hosted GitLab

### 🙏 Credit

Issue discovered and reported by user experiencing failures with self-hosted GitLab instance (`gitlab.eumediatools.com`). The LLM showed excellent problem-solving by working around broken instructions, but the command file itself required a complete rewrite.

---

## [2025-10-08] - GitLab Edition Fork

### 🎯 Overview
Complete migration of CCPM from GitHub to GitLab, replacing all GitHub integrations with native GitLab support. This fork maintains all original functionality while leveraging GitLab's superior issue relationships and unified DevOps platform.

### ✨ Major Changes
- **Complete GitLab Migration**
  - Replaced `gh` CLI with `glab` CLI throughout entire codebase
  - Updated 43 references across 14 files
  - Migrated all command files, scripts, and documentation
  - Native GitLab issue linking (no extensions required)

- **Simplified Installation**
  - One-line installation command using git clone
  - No external hosting dependencies
  - Fast setup with `--depth 1` clone

- **Updated Terminology**
  - GitHub → GitLab across all documentation
  - Issue "comments" → "notes" in API interactions
  - Issue `number` → `iid` (internal ID)
  - Issue state `open` → `opened`

### 🔄 Technical Changes
- **CLI Commands**: All `gh` commands replaced with `glab` equivalents
- **URLs**: Updated from `github.com/owner/repo/issues/N` to `gitlab.com/owner/repo/-/issues/N`
- **Authentication**: `glab auth login` instead of `gh auth login`
- **Issue Creation**: Uses `glab issue create --description` with native linking
- **Frontmatter**: `github:` field replaced with `gitlab:` field

### 📝 Documentation Updates
- README.md: Complete GitLab Edition branding
- CLAUDE.md: Updated all GitHub references to GitLab
- All command files migrated to GitLab syntax
- Installation guide simplified

### 🔗 Links
- **GitLab Edition Repository**: https://github.com/lorenzotomasdiez/ccpm-gitlab
- **Original Project**: https://github.com/automazeio/ccpm
- **Author**: [Lorenzo Tomas Diez](https://github.com/lorenzotomasdiez)

---

## Original Project History

## [2025-01-24] - Major Cleanup & Issue Resolution Release

### 🎯 Overview
Resolved 10 of 12 open GitHub issues, modernized command syntax, improved documentation, and enhanced system accuracy. This release focuses on stability, usability, and addressing community feedback.

### ✨ Added
- **Local Mode Support** ([#201](https://github.com/automazeio/ccpm/issues/201))
  - Created `LOCAL_MODE.md` with comprehensive offline workflow guide
  - All core commands (prd-new, prd-parse, epic-decompose) work without GitHub
  - Clear distinction between local-only vs GitHub-dependent commands

- **Automatic GitHub Label Creation** ([#544](https://github.com/automazeio/ccpm/issues/544))
  - Enhanced `init.sh` to automatically create `epic` and `task` labels
  - Proper colors: `epic` (green #0E8A16), `task` (blue #1D76DB)  
  - Eliminates manual label setup during project initialization

- **Context Creation Accuracy Safeguards** ([#48](https://github.com/automazeio/ccpm/issues/48))
  - Added mandatory self-verification checkpoints in context commands
  - Implemented evidence-based analysis requirements
  - Added uncertainty flagging with `⚠️ Assumption - requires verification`
  - Enhanced both `/context:create` and `/context:update` with accuracy validation

### 🔄 Changed
- **Modernized Command Syntax** ([#531](https://github.com/automazeio/ccpm/issues/531))
  - Updated 14 PM command files to use concise `!bash` execution pattern
  - Simplified `allowed-tools` frontmatter declarations
  - Reduced token usage and improved Claude Code compatibility

- **Comprehensive README Overhaul** ([#323](https://github.com/automazeio/ccpm/issues/323))
  - Clarified PRD vs Epic terminology and definitions
  - Streamlined workflow explanations and removed redundant sections
  - Fixed installation instructions and troubleshooting guidance
  - Improved overall structure and navigation

### 📋 Research & Community Engagement
- **Multi-Tracker Support Analysis** ([#200](https://github.com/automazeio/ccpm/issues/200))
  - Researched CLI availability for Linear, Trello, Azure DevOps, Jira
  - Identified Linear as best first alternative to GitHub Issues
  - Provided detailed implementation roadmap for future development

- **GitLab Support Research** ([#588](https://github.com/automazeio/ccpm/issues/588))  
  - Confirmed strong `glab` CLI support for GitLab integration
  - Invited community contributor to submit existing GitLab implementation as PR
  - Updated project roadmap to include GitLab as priority platform

### 🐛 Clarified Platform Limitations
- **Windows Shell Compatibility** ([#609](https://github.com/automazeio/ccpm/issues/609))
  - Documented as Claude Code platform limitation (requires POSIX shell)
  - Provided workarounds and alternative solutions

- **Codex CLI Integration** ([#585](https://github.com/automazeio/ccpm/issues/585))
  - Explained future multi-AI provider support in new CLI architecture

- **Parallel Worker Agent Behavior** ([#530](https://github.com/automazeio/ccpm/issues/530))
  - Clarified agent role as coordinator, not direct coder
  - Provided implementation guidance and workarounds

### 🔒 Security
- **Privacy Documentation Fix** ([#630](https://github.com/automazeio/ccpm/issues/630))
  - Verified resolution via PR #631 (remove real repository references)

### 💡 Proposed Features
- **Bug Handling Workflow** ([#654](https://github.com/automazeio/ccpm/issues/654))
  - Designed `/pm:attach-bug` command for automated bug tracking
  - Proposed lightweight sub-issue integration with existing infrastructure
  - Community feedback requested on implementation approach

### 📊 Issues Resolved
**Closed**: 10 issues  
**Active Proposals**: 1 issue (#654)  
**Remaining Open**: 1 issue (#653)

#### Closed Issues:
- [#630](https://github.com/automazeio/ccpm/issues/630) - Privacy: Remove real repo references ✅  
- [#609](https://github.com/automazeio/ccpm/issues/609) - Windows shell error (platform limitation) ✅
- [#585](https://github.com/automazeio/ccpm/issues/585) - Codex CLI compatibility (architecture update) ✅  
- [#571](https://github.com/automazeio/ccpm/issues/571) - Figma MCP support (platform feature) ✅
- [#531](https://github.com/automazeio/ccpm/issues/531) - Use !bash in custom slash commands ✅
- [#323](https://github.com/automazeio/ccpm/issues/323) - Improve README.md ✅
- [#201](https://github.com/automazeio/ccpm/issues/201) - Local-only mode support ✅
- [#200](https://github.com/automazeio/ccpm/issues/200) - Multi-tracker support research ✅  
- [#588](https://github.com/automazeio/ccpm/issues/588) - GitLab support research ✅
- [#48](https://github.com/automazeio/ccpm/issues/48) - Context creation inaccuracies ✅
- [#530](https://github.com/automazeio/ccpm/issues/530) - Parallel worker coding operations ✅
- [#544](https://github.com/automazeio/ccpm/issues/544) - Auto-create labels during init ✅
- [#947](https://github.com/automazeio/ccpm/issues/947) - Project roadmap update ✅

### 🛠️ Technical Details
- **Files Modified**: 16 core files + documentation
- **New Files**: `LOCAL_MODE.md`, `CONTEXT_ACCURACY.md`  
- **Commands Updated**: All 14 PM slash commands modernized
- **Backward Compatibility**: Fully maintained
- **Dependencies**: No new external dependencies added

### 🏗️ Project Health
- **Issue Resolution Rate**: 83% (10/12 issues closed)
- **Documentation Coverage**: Significantly improved
- **Community Engagement**: Active contributor invitation and feedback solicitation
- **Code Quality**: Enhanced accuracy safeguards and validation

### 🚀 Next Steps
1. Community feedback on bug handling proposal (#654)
2. GitLab integration PR review and merge
3. Linear platform integration (pending demand)
4. Enhanced testing and validation workflows

---

*This release represents a major stability and usability milestone for CCPM, addressing the majority of outstanding community issues while establishing a foundation for future multi-platform support.*