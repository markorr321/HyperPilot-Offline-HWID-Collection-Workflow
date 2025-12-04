@echo off
REM HyperPilot AutoPilot HWID Collection Workflow Launcher
REM This batch file launches the PowerShell workflow script

echo Starting HyperPilot HWID Collection Workflow...
echo.

REM Check if running PowerShell 7, fallback to Windows PowerShell
where pwsh >nul 2>nul
if %errorlevel% == 0 (
    pwsh.exe -ExecutionPolicy Bypass -File "%~dp0HyperPilot-HWID-Workflow.ps1"
) else (
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0HyperPilot-HWID-Workflow.ps1"
)
