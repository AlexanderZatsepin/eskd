param(
    [string]$Branch = "master",
    [int]$Port = 8010,
    [int]$IntervalSeconds = 30,
    [switch]$Once
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$Python = Join-Path $ProjectRoot ".venv\Scripts\python.exe"
$PidFile = Join-Path $ProjectRoot ".runserver.pid"
$LogDir = Join-Path $ProjectRoot "logs"
$OutLog = Join-Path $LogDir "runserver.out.log"
$ErrLog = Join-Path $LogDir "runserver.err.log"

function Write-DeployLog {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message"
}

function Invoke-InProject {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    $process = Start-Process `
        -FilePath $FilePath `
        -ArgumentList $Arguments `
        -WorkingDirectory $ProjectRoot `
        -NoNewWindow `
        -Wait `
        -PassThru

    if ($process.ExitCode -ne 0) {
        throw "$FilePath $($Arguments -join ' ') failed with exit code $($process.ExitCode)"
    }
}

function Assert-Ready {
    if (-not (Test-Path $Python)) {
        throw "Python venv not found: $Python. Create it and install requirements first."
    }

    Invoke-InProject "git" @("rev-parse", "--is-inside-work-tree")

    $status = git -C $ProjectRoot status --porcelain --untracked-files=no
    if ($status) {
        throw "Working tree is not clean. Commit or discard local changes before auto deploy."
    }
}

function Stop-Runserver {
    if (-not (Test-Path $PidFile)) {
        return
    }

    $processId = Get-Content $PidFile -ErrorAction SilentlyContinue
    if ($processId) {
        $process = Get-Process -Id ([int]$processId) -ErrorAction SilentlyContinue
        if ($process) {
            Write-DeployLog "Stopping old runserver PID $processId"
            Stop-Process -Id ([int]$processId) -Force
        }
    }

    Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
}

function Start-Runserver {
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir | Out-Null
    }

    Stop-Runserver

    Write-DeployLog "Starting Django runserver on 0.0.0.0:$Port"
    $process = Start-Process `
        -FilePath $Python `
        -ArgumentList @("manage.py", "runserver", "0.0.0.0:$Port") `
        -WorkingDirectory $ProjectRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $OutLog `
        -RedirectStandardError $ErrLog `
        -PassThru

    Set-Content -Path $PidFile -Value $process.Id
    Write-DeployLog "Runserver PID $($process.Id). Logs: $OutLog"
}

function Deploy-IfChanged {
    Assert-Ready

    Write-DeployLog "Fetching origin/$Branch"
    Invoke-InProject "git" @("fetch", "origin", $Branch)

    $local = (git -C $ProjectRoot rev-parse HEAD).Trim()
    $remote = (git -C $ProjectRoot rev-parse "origin/$Branch").Trim()

    if ($local -eq $remote) {
        Write-DeployLog "No new commit. Current HEAD: $local"
        return
    }

    Write-DeployLog "New commit found: $local -> $remote"
    Invoke-InProject "git" @("pull", "--ff-only", "origin", $Branch)
    Invoke-InProject $Python @("manage.py", "migrate", "--noinput")
    Start-Runserver
    Write-DeployLog "Deploy complete."
}

Set-Location $ProjectRoot

if ($Once) {
    Deploy-IfChanged
    exit 0
}

Write-DeployLog "Auto deploy watcher started for origin/$Branch every $IntervalSeconds seconds."
Write-DeployLog "Press Ctrl+C to stop watcher. Django runserver keeps running in background."

while ($true) {
    try {
        Deploy-IfChanged
    }
    catch {
        Write-DeployLog "ERROR: $($_.Exception.Message)"
    }

    Start-Sleep -Seconds $IntervalSeconds
}
