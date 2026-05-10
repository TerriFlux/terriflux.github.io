#!/usr/bin/env pwsh
# Reproduit en local ce que fait .github/workflows/build.yml
# Builde tous les exemples React et assemble le dossier public/.
#
# Usage:
#   ./build-local.ps1                 # build + serve sur http://localhost:8000
#   ./build-local.ps1 -Force          # force npm install partout (apres update repo)
#   ./build-local.ps1 -NoServe        # build seulement, pas de serveur
#   ./build-local.ps1 -Port 8080      # change le port

param(
    [string]$OpenSankeyPath = "D:\Dev\sankeyapp\dev\sankeyapplication\submodules\OpenSankey+\submodules\OpenSankey",
    [switch]$Force,
    [switch]$NoServe,
    [int]$Port = 8000
)

$ErrorActionPreference = 'Stop'

# Aligne sur EXAMPLE_MATRIX dans .github/workflows/build.yml
$examples = @(
    "1.0.7/viewer",
    "1.0.7/editor",
    "1.1.1/viewer",
    "1.1.1/editor",
    "1.1.2/viewer",
    "1.1.2/editor"
)

$root = $PSScriptRoot
$publicDir = Join-Path $root "public"

# Verifs prealables -----------------------------------------------------------

if (-not (Test-Path $OpenSankeyPath)) {
    Write-Host "[ERR] OpenSankey introuvable: $OpenSankeyPath" -ForegroundColor Red
    Write-Host "      Passe -OpenSankeyPath <chemin> en parametre." -ForegroundColor Yellow
    exit 1
}

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "[ERR] npm introuvable dans le PATH." -ForegroundColor Red
    exit 1
}

function Find-Python {
    if (Get-Command py -ErrorAction SilentlyContinue) { return (Get-Command py).Source }
    foreach ($name in 'python', 'python3') {
        $cmds = Get-Command $name -All -ErrorAction SilentlyContinue
        foreach ($c in $cmds) {
            if ($c.Source -and ($c.Source -notlike '*\WindowsApps\*')) { return $c.Source }
        }
    }
    foreach ($p in @(
        "D:\miniconda3\python.exe",
        "C:\miniconda3\python.exe",
        "$env:USERPROFILE\miniconda3\python.exe"
    )) { if (Test-Path $p) { return $p } }
    return $null
}

# Preparation public/ ---------------------------------------------------------

Write-Host "[INFO] Preparation de $publicDir" -ForegroundColor Cyan
if (Test-Path $publicDir) { Remove-Item -Recurse -Force $publicDir }
New-Item -ItemType Directory -Path $publicDir | Out-Null

Copy-Item (Join-Path $root "index.html") $publicDir
if (Test-Path (Join-Path $root "favicon.ico")) {
    Copy-Item (Join-Path $root "favicon.ico") $publicDir
}

# Build de chaque exemple -----------------------------------------------------

$failed = @()
$skipped = @()
$built = @()

foreach ($ex in $examples) {
    $srcDir = Join-Path $OpenSankeyPath ("examples\" + $ex.Replace('/', '\'))
    $destDir = Join-Path $publicDir $ex.Replace('/', '\')

    Write-Host ""
    Write-Host "----------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[BUILD] $ex" -ForegroundColor Cyan
    Write-Host "        src: $srcDir" -ForegroundColor DarkGray

    if (-not (Test-Path $srcDir)) {
        Write-Host "[WARN] source introuvable, skip." -ForegroundColor Yellow
        $skipped += $ex
        continue
    }

    Push-Location $srcDir
    try {
        # Les commandes externes (npm) ecrivent leurs warnings sur stderr ;
        # avec $ErrorActionPreference = 'Stop' au niveau script ca devient
        # une erreur terminale. On bascule en 'Continue' juste pour ces appels.
        $prevPref = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'

        $needInstall = $Force -or (-not (Test-Path "node_modules"))
        if ($needInstall) {
            Write-Host "[STEP] npm install (peut prendre 1-2 min)..." -ForegroundColor DarkGray
            cmd /c "npm install --no-audit --no-fund --prefer-offline 2>&1"
            if ($LASTEXITCODE -ne 0) { throw "npm install a echoue (exit $LASTEXITCODE)" }
        }
        else {
            Write-Host "[SKIP] node_modules present (utilise -Force pour reinstaller)" -ForegroundColor DarkGray
        }

        $env:PUBLIC_URL = "."
        Write-Host "[STEP] npm run build (PUBLIC_URL=.)..." -ForegroundColor DarkGray
        cmd /c "npm run build 2>&1"
        if ($LASTEXITCODE -ne 0) { throw "npm run build a echoue (exit $LASTEXITCODE)" }

        $ErrorActionPreference = $prevPref

        if (-not (Test-Path "build")) { throw "le dossier build/ n'a pas ete cree" }

        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        Copy-Item -Recurse -Force "build\*" $destDir
        Write-Host "[OK]   copie vers $destDir" -ForegroundColor Green
        $built += $ex
    }
    catch {
        Write-Host "[ERR]  $_" -ForegroundColor Red
        $failed += $ex
    }
    finally {
        Pop-Location
        Remove-Item Env:PUBLIC_URL -ErrorAction SilentlyContinue
    }
}

# Recap -----------------------------------------------------------------------

Write-Host ""
Write-Host "====================================================" -ForegroundColor DarkGray
Write-Host "Recapitulatif:" -ForegroundColor Cyan
Write-Host ("  Buildes  ({0}): {1}" -f $built.Count,   ($built   -join ', ')) -ForegroundColor Green
if ($skipped.Count) { Write-Host ("  Skippes  ({0}): {1}" -f $skipped.Count, ($skipped -join ', ')) -ForegroundColor Yellow }
if ($failed.Count)  { Write-Host ("  Echoues  ({0}): {1}" -f $failed.Count,  ($failed  -join ', ')) -ForegroundColor Red }

if ($built.Count -eq 0) {
    Write-Host "Aucun build reussi - pas de serveur a lancer." -ForegroundColor Red
    exit 1
}

# Serveur ---------------------------------------------------------------------

if ($NoServe) {
    Write-Host ""
    Write-Host "Build OK. Pour servir manuellement:" -ForegroundColor Cyan
    Write-Host ("  cd `"{0}`"; python -m http.server {1}" -f $publicDir, $Port) -ForegroundColor White
    exit 0
}

$python = Find-Python
if (-not $python) {
    Write-Host "[ERR] Python introuvable, impossible de lancer le serveur." -ForegroundColor Red
    Write-Host ("      Build pret dans: {0}" -f $publicDir) -ForegroundColor Yellow
    exit 1
}

$url = "http://localhost:$Port/"
Write-Host ""
Write-Host ("[GO] Vitrine sur {0}" -f $url) -ForegroundColor Green
Write-Host "     Ctrl+C pour arreter." -ForegroundColor DarkGray
Start-Process $url
Push-Location $publicDir
try { & $python -m http.server $Port } finally { Pop-Location }
