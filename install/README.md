# Quick Install - GitLab Edition

## Recommended: One-Line Installation

Navigate to your project root directory and run:

### Unix/Linux/macOS
```bash
git clone --depth 1 https://github.com/lorenzotomasdiez/ccpm-gitlab.git .claude && rm -rf .claude/.git
```

### Windows (PowerShell)
```powershell
git clone --depth 1 https://github.com/lorenzotomasdiez/ccpm-gitlab.git .claude; Remove-Item -Recurse -Force .claude/.git
```

### Windows (cmd)
```cmd
git clone --depth 1 https://github.com/lorenzotomasdiez/ccpm-gitlab.git .claude && rmdir /s /q .claude\.git
```

## What This Does

- Clones the CCPM GitLab Edition into your project's `.claude` directory
- Uses `--depth 1` to download only the latest version (faster)
- Removes the `.git` directory so it's not tracked as a submodule
- Ready to use immediately with `/pm:init`

## After Installation

1. **Initialize the system**:
   ```bash
   /pm:init
   ```

2. **Create your project's CLAUDE.md**:
   ```bash
   /init
   ```

3. **Start using CCPM**:
   ```bash
   /pm:prd-new your-feature
   ```

## Alternative: Manual Installation

If you prefer manual control:

1. Clone to a temporary location:
   ```bash
   git clone https://github.com/lorenzotomasdiez/ccpm-gitlab.git /tmp/ccpm-gitlab
   ```

2. Copy the `ccpm` directory to your project:
   ```bash
   cp -r /tmp/ccpm-gitlab/ccpm .claude
   ```

3. Clean up:
   ```bash
   rm -rf /tmp/ccpm-gitlab
   ```
