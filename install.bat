@echo off
setlocal

echo ARC Raiders CLI - Install
echo -------------------------

REM Get the script's directory
set "ScriptPath=%~dp0"
set "ScriptPath=%ScriptPath:~0,-1%"

echo [*] Creating 'arc.bat' alias...
(
    echo @echo off
    echo powershell -ExecutionPolicy Bypass -File "%%~dp0ARCSearch.ps1" %%*
) > "%~dp0arc.bat"

echo [*] Adding '%ScriptPath%' to User PATH...

REM PowerShell command to safely add the directory to the user's PATH
powershell -Command "$UserPath = [Environment]::GetEnvironmentVariable('Path', 'User'); if (-not ($UserPath -split ';' | Where-Object { $_ -eq '%ScriptPath%' })) { $NewPath = ($UserPath.TrimEnd(';') + ';%ScriptPath%').Trim(';'); [Environment]::SetEnvironmentVariable('Path', $NewPath, 'User'); echo '[+] PATH updated successfully.'; echo '[!] NOTE: You must restart your terminal for this to take effect.'; } else { echo '[+] Current directory is already in PATH.'; }"

echo.
echo Installation Complete!
echo You can now type 'arc ^<query^>' from any new terminal window.
pause
goto :eof
