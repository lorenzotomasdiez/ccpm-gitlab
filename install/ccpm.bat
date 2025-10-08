@echo off

set REPO_URL=https://github.com/lorenzotomasdiez/ccpm-gitlab.git
set TARGET_DIR=.claude

echo.
echo Installing Claude Code PM - GitLab Edition
echo ===========================================
echo.
echo Cloning from %REPO_URL%...
echo.

git clone --depth 1 %REPO_URL% %TARGET_DIR%

if %ERRORLEVEL% EQU 0 (
    echo Success! Cleaning up...
    rmdir /s /q %TARGET_DIR%\.git 2>nul
    del /q %TARGET_DIR%\.gitignore 2>nul
    rmdir /s /q %TARGET_DIR%\install 2>nul
    echo.
    echo Installation complete!
    echo.
    echo Next steps:
    echo   1. Run: /pm:init
    echo   2. Run: /init
    echo   3. Start with: /pm:prd-new your-feature
) else (
    echo Error: Failed to clone repository.
    exit /b 1
)
