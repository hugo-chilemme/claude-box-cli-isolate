#Requires -Version 5.0
$ErrorActionPreference = "Stop"

Write-Host "=== claude-box setup (Windows) ==="

# --- 0. Check Docker ---
try {
    docker ps | Out-Null
} catch {
    Write-Host "ERROR: Docker is not responding. Start Docker Desktop first." -ForegroundColor Red
    exit 1
}

# --- 1. Build image ---
Write-Host "[1/3] Building Docker image..."
$Dockerfile = Join-Path $env:TEMP "Dockerfile.claudebox"
@"
FROM node:22
RUN npm install -g @anthropic-ai/claude-code
WORKDIR /workspace
ENTRYPOINT ["claude"]
"@ | Set-Content $Dockerfile
docker build -t claude-box:latest -f $Dockerfile $env:TEMP

# --- 2. Auth volume ---
Write-Host "[2/3] Creating persistent auth volume..."
docker volume create claude-auth | Out-Null

# --- 3. Install script ---
Write-Host "[3/3] Installing script..."
$ToolsDir = "C:\Tools"
New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null
$ScriptPath = Join-Path $ToolsDir "claude-box.ps1"

@'
#Requires -Version 5.0
param(
    [Parameter(Position=0)][string]$Cmd,
    [Parameter(Position=1, ValueFromRemainingArguments=$true)][string[]]$Items
)
$ErrorActionPreference = "Stop"

switch ($Cmd) {
    "up" {
        if (-not $Items) { Write-Host "Usage: claude-box up <item1> [item2] ..."; exit 1 }

        $Mounts = @()
        foreach ($Item in $Items) {
            $Abs = Join-Path (Get-Location) $Item
            if (-not (Test-Path $Abs)) { Write-Host "ERROR: ''$Item'' does not exist" -ForegroundColor Red; exit 1 }
            $AbsUnix = $Abs -replace ''\\'',''/''
            $ItemUnix = $Item -replace ''\\'',''/''
            $Mounts += "-v"
            $Mounts += "${AbsUnix}:/workspace/${ItemUnix}"
            Write-Host "  mounted: $Item -> /workspace/$ItemUnix (live sync)"
        }

        Write-Host "Starting Claude (container-isolated, /workspace live-synced)"
        docker run -it --rm `
            @Mounts `
            -v "claude-auth:/root/.claude" `
            -e "CLAUDE_CONFIG_DIR=/root/.claude" `
            -w /workspace `
            --entrypoint bash `
            claude-box:latest `
            -c ''cat > /workspace/CLAUDE.md <<EOF
# Workspace rule
All created or modified files must go DIRECTLY in /workspace. This directory is live-synced with the user machine.
EOF
exec claude''

        Write-Host "Cleaning up claude-box files..."
        Remove-Item -Recurse -Force (Join-Path (Get-Location) ".claude") -ErrorAction SilentlyContinue
        Remove-Item -Force (Join-Path (Get-Location) "CLAUDE.md") -ErrorAction SilentlyContinue
        Write-Host "Done."
    }

    "down" {
        Write-Host "Cleaning up claude-box containers..."
        $ids = docker ps -a --filter "ancestor=claude-box:latest" -q
        if ($ids) { $ids | ForEach-Object { docker rm -f $_ } }
        Remove-Item -Recurse -Force (Join-Path (Get-Location) ".claude") -ErrorAction SilentlyContinue
        Remove-Item -Force (Join-Path (Get-Location) "CLAUDE.md") -ErrorAction SilentlyContinue
        Write-Host "Done."
    }

    default {
        Write-Host "claude-box <up|down>"
        Write-Host "  up <items...>   mount each item into /workspace and start Claude"
        Write-Host "  down            clean up containers and residual files"
    }
}
'@ | Set-Content $ScriptPath -Encoding UTF8

# --- Alias in PowerShell profile ---
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Force -Path $PROFILE | Out-Null
}
$AliasLine = "function claude-box { & C:\Tools\claude-box.ps1 @args }"
$ProfileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if ($ProfileContent -notmatch [regex]::Escape($AliasLine)) {
    Add-Content $PROFILE "`n$AliasLine"
    Write-Host "  Alias added to profile."
} else {
    Write-Host "  Alias already present."
}

Write-Host ""
Write-Host "=== Done ==="
Write-Host "Reopen PowerShell, then:"
Write-Host "  cd C:\project"
Write-Host "  claude-box up config.json app\routes"
Write-Host "  claude-box down"
Write-Host ""
Write-Host "(First run: use /login inside Claude, then it is saved)"
