@echo off
title Beyond Chatbots - KEEP THIS WINDOW OPEN during the talk
cd /d "%~dp0"
echo.
echo   Beyond Chatbots demo
echo   ---------------------------------------------------------------
echo   Starting... this takes 1-2 minutes.
echo   Chrome will open by itself when the demo is ready.
echo.
echo   KEEP THIS WINDOW OPEN during the talk. Close it to stop the demo.
echo   ---------------------------------------------------------------
echo.

rem Already running (e.g. you double-clicked twice)? Just open Chrome.
powershell -NoProfile -Command "try { $r=[Net.WebRequest]::Create('http://localhost:8080/main.dart.js'); $r.Timeout=2000; $r.GetResponse().Close(); exit 0 } catch { exit 1 }"
if %errorlevel%==0 (
  echo   The demo is already running. Opening Chrome...
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\open-when-ready.ps1"
  timeout /t 3 >nul
  exit /b
)

rem Opens Chrome as soon as the demo is ready (runs in the background).
start "" /b powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0tools\open-when-ready.ps1"

rem --no-web-resources-cdn serves Flutter's engine from this PC, not Google's
rem servers, so the demo still opens with no internet.
rem Extra arguments are passed through, e.g. --dart-define=FORCE_DEMO=true
C:\flutter\bin\flutter.bat run -d web-server --release --web-port 8080 --no-web-resources-cdn %*

echo.
echo   The demo has stopped. If you saw an error above, take a photo of it.
pause
