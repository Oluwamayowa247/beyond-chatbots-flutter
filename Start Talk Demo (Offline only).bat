@echo off
rem Same as "Start Talk Demo", but always uses the scripted Offline mode.
call "%~dp0Start Talk Demo.bat" --dart-define=FORCE_DEMO=true
