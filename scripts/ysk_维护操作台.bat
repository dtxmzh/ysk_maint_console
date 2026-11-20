@echo off
rem ysk_wei hu cao zuo tai entry - window front-end exe, terminal mode via arg
rem 2026-11-20 renamed from wei hu kong zhi tai (avoid clash with Windows components).
rem GUI:  ysk_维护操作台.bat        -> 维护操作台窗口版 (v1.0.0+)
rem TTY:  ysk_维护操作台.bat tty    -> 原终端交互版 ps1
if /i "%~1"=="tty" (
  where pwsh >nul 2>nul
  if %errorlevel%==0 (
    call pwsh -NoProfile -ExecutionPolicy Bypass -File "D:\ProgramFiles\ysk_toolsun\ysk_maint_console.ps1"
  ) else (
    call powershell -NoProfile -ExecutionPolicy Bypass -File "D:\ProgramFiles\ysk_toolsun\ysk_maint_console.ps1"
  )
  exit /b %errorlevel%
)
start "" "D:\ProgramFiles\ysk_tools\ysk_maint_console\ysk_maint_console.exe"
