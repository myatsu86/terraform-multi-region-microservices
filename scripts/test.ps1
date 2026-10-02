# Test script for customer-profile on Windows
# Run PowerShell as Administrator:
#   Set-ExecutionPolicy -Scope Process Bypass -Force
#   .\test-customer-profile.ps1

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Application folder already present on the Windows server
$AppDir = "C:\Users\Administrator\Downloads\fake_service_windows_amd64"

# Supports either filename
$PossibleAppPaths = @(
    (Join-Path $AppDir "fake-service.exe"),
    (Join-Path $AppDir "fake-service")
)

$AppPath = $PossibleAppPaths |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1

if (-not $AppPath) {
    throw "Application not found. Checked: $($PossibleAppPaths -join ', ')"
}

# Remove the Internet-download security flag, if Windows attached one
Unblock-File -Path $AppPath -ErrorAction SilentlyContinue

# App settings
$ServicePort = 9091
$env:LISTEN_ADDR   = "0.0.0.0:$ServicePort"
$env:UPSTREAM_URIS = "http://internal-account-alb-1716877376.us-east-1.elb.amazonaws.com"
$env:NAME          = "customer-profile-$env:COMPUTERNAME"
$env:MESSAGE       = "HelloCloudBank | Retail Banking | customer-profile-svc | hostname=$env:COMPUTERNAME"

# Log locations
$LogDir = Join-Path $AppDir "logs"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

$StdoutLog = Join-Path $LogDir "app.log"
$StderrLog = Join-Path $LogDir "app-error.log"

# Allow inbound traffic to the application port in Windows Firewall
$FirewallRuleName = "Allow customer-profile TCP $ServicePort"

if (-not (Get-NetFirewallRule -DisplayName $FirewallRuleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule `
        -DisplayName $FirewallRuleName `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort $ServicePort `
        -Action Allow `
        -Profile Any | Out-Null
}

# Stop a previous fake-service process, if one is already running
Get-Process -Name "fake-service" -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue

# Start the application in the background
$Process = Start-Process `
    -FilePath $AppPath `
    -WorkingDirectory $AppDir `
    -RedirectStandardOutput $StdoutLog `
    -RedirectStandardError $StderrLog `
    -PassThru

Start-Sleep -Seconds 5

if ($Process.HasExited) {
    Write-Host ""
    Write-Host "fake-service stopped immediately."
    Write-Host "Error log: $StderrLog"
    Write-Host ""
    if (Test-Path $StderrLog) {
        Get-Content $StderrLog -Tail 100
    }
    exit 1
}

Write-Host ""
Write-Host "customer-profile started successfully."
Write-Host "Application: $AppPath"
Write-Host "Process ID : $($Process.Id)"
Write-Host "Port       : $ServicePort"
Write-Host "Logs       : $LogDir"
Write-Host ""
Write-Host "Verify with:"
Write-Host "  Get-NetTCPConnection -LocalPort $ServicePort -State Listen"
Write-Host "  Get-Content `"$StdoutLog`" -Tail 50"