# Waits until the demo is being served, then opens it in your normal Chrome.
# Called by "Start Talk Demo.bat". Gives up after 10 minutes.
param([string]$Url = 'http://localhost:8080')

function Test-AppReady {
    try {
        # Only fetch the headers of the compiled app, never the 3.6 MB body.
        $req = [System.Net.WebRequest]::Create("$Url/main.dart.js")
        $req.Timeout = 3000
        $resp = $req.GetResponse()
        $ok = [int]$resp.StatusCode -eq 200
        $resp.Close()
        return $ok
    } catch {
        return $false
    }
}

$deadline = (Get-Date).AddMinutes(10)
while (-not (Test-AppReady)) {
    if ((Get-Date) -gt $deadline) { exit 1 }
    Start-Sleep -Seconds 2
}

$chrome = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($chrome) { Start-Process $chrome $Url } else { Start-Process $Url }
