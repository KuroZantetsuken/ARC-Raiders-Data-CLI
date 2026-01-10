@echo off
setlocal

echo ARC Raiders CLI - Uninstall
echo ---------------------------

REM Get the script's directory for removal
set "ScriptPath=%~dp0"
set "ScriptPath=%ScriptPath:~0,-1%"

echo [*] Removing '%ScriptPath%' from User PATH...

REM PowerShell command to safely remove the directory from the user's PATH
powershell -Command "$UserPath = [Environment]::GetEnvironmentVariable('Path', 'User'); $PathParts = $UserPath -split ';' | Where-Object { $_ -ne '' }; if ($PathParts -contains '%ScriptPath%') { $NewParts = $PathParts | Where-Object { $_ -ne '%ScriptPath%' }; $CleanPath = $NewParts -join ';'; [Environment]::SetEnvironmentVariable('Path', $CleanPath, 'User'); echo '[-] Removed from PATH.'; } else { echo '[+] Current directory is not in PATH.'; }"

echo [*] Removing 'arc.bat' alias...
if exist "%~dp0arc.bat" (
    del "%~dp0arc.bat"
    echo [-] Removed 'arc.bat'.
) else (
    echo [x] 'arc.bat' not found.
)

echo.
echo Uninstallation Complete.
echo You may delete this folder now.
pause
goto :eof
