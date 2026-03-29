# organize_media_pass2.ps1
# Second pass: handles the numbered files 01-123, .ts files, and junk .js files
# Run with: Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass; & ".\organize_media_pass2.ps1"

$root = "D:\Media\x"

# The garbled encoding: UTF-8 em-dash bytes read as Latin-1 = â (U+00E2) + € (U+20AC) + " (U+201C)
# Replace with proper em dash –  (U+2013)
$garbled  = [string][char]0x00E2 + [string][char]0x20AC + [string][char]0x201C
$emdash   = [string][char]0x2013

function Fix-Name($name) {
    return $name.Replace($garbled, $emdash)
}

$counts = @{ Collection = 0; JAV = 0; BBC = 0; Deleted = 0 }

# ─────────────────────────────────────────────
# STEP 1 — Delete junk .js web player files
# ─────────────────────────────────────────────
Write-Host "`n=== Deleting junk .js files ===" -ForegroundColor Cyan
$jsFiles = @("api.js","app.1aad5686.js","hls.min.js","lib.js","main.js",
             "outstream.video.js","plyr-plugin-thumbnail.js","plyr.min.js")
foreach ($js in $jsFiles) {
    $p = Join-Path $root $js
    if (Test-Path -LiteralPath $p) {
        Remove-Item -LiteralPath $p
        Write-Host "[DELETED] $js" -ForegroundColor Red
        $counts.Deleted++
    }
}

# ─────────────────────────────────────────────
# STEP 2 — Move .ts files
# ─────────────────────────────────────────────
Write-Host "`n=== .ts files ===" -ForegroundColor Cyan

# BBC Hypno PMV .ts -> BBC - Interracial\
$bbcTs = Get-ChildItem -LiteralPath $root -Filter "Big Black Cock - Hypno Pmv*.ts" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($bbcTs) {
    $destDir = Join-Path $root "BBC - Interracial"
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    $dest = Join-Path $destDir "BBC - Big Black Cock Hypno PMV.ts"
    if (-not (Test-Path -LiteralPath $dest)) {
        Move-Item -LiteralPath $bbcTs.FullName -Destination $dest
        Write-Host "[OK] $($bbcTs.Name) -> BBC - Interracial\BBC - Big Black Cock Hypno PMV.ts" -ForegroundColor Green
        $counts.BBC++
    }
}

# JAV .ts files -> JAV\
$javDir = Join-Path $root "JAV"
New-Item -ItemType Directory -Path $javDir -Force | Out-Null

$javTs = @(
    @("DVAJ-450*",  "DVAJ-450 - Shes Slowly Grinding On Him.ts"),
    @("HMN-170*",   "HMN-170 - Back Face of a Female Boss.ts"),
    @("IPX-620*",   "IPX-620 - Nasty Cowgirl of an Older Sister.ts")
)
foreach ($jav in $javTs) {
    $found = Get-ChildItem -LiteralPath $root -Filter $jav[0] -ErrorAction SilentlyContinue |
             Where-Object { $_.Extension -eq ".ts" } | Select-Object -First 1
    if ($found) {
        $dest = Join-Path $javDir $jav[1]
        if (-not (Test-Path -LiteralPath $dest)) {
            Move-Item -LiteralPath $found.FullName -Destination $dest
            Write-Host "[OK] $($found.Name) -> JAV\$($jav[1])" -ForegroundColor Green
            $counts.JAV++
        }
    }
}

# JAV sidecar .md and .srt files (74 – DVAJ-450 and 92 – IPX-620)
$sidecarPatterns = @(
    @("*DVAJ-450*", "DVAJ-450"),
    @("*IPX-620*",  "IPX-620")
)
foreach ($sc in $sidecarPatterns) {
    foreach ($ext in @(".md", ".srt")) {
        $found = Get-ChildItem -LiteralPath $root -Filter ($sc[0]) -ErrorAction SilentlyContinue |
                 Where-Object { $_.Extension -eq $ext } | Select-Object -First 1
        if ($found) {
            $cleanName = $sc[1] + $ext
            $dest = Join-Path $javDir $cleanName
            if (-not (Test-Path -LiteralPath $dest)) {
                Move-Item -LiteralPath $found.FullName -Destination $dest
                Write-Host "[OK] $($found.Name) -> JAV\$cleanName" -ForegroundColor Green
                $counts.JAV++
            }
        }
    }
}

# ─────────────────────────────────────────────
# STEP 3 — Fix encoding and move numbered files to Collection\
# ─────────────────────────────────────────────
Write-Host "`n=== Numbered collection files (encoding fix + move) ===" -ForegroundColor Cyan
$collDir = Join-Path $root "Collection"
New-Item -ItemType Directory -Path $collDir -Force | Out-Null

# Match any file at the root that starts with 1-3 digits followed by a space
$numberedFiles = Get-ChildItem -LiteralPath $root -File |
    Where-Object { $_.Name -match '^\d{1,3} ' }

foreach ($f in $numberedFiles) {
    $fixedName = Fix-Name $f.Name
    $dest = Join-Path $collDir $fixedName
    if (-not (Test-Path -LiteralPath $dest)) {
        Move-Item -LiteralPath $f.FullName -Destination $dest
        if ($fixedName -ne $f.Name) {
            Write-Host "[OK] (fixed) $($f.Name)  ->  Collection\$fixedName" -ForegroundColor Green
        } else {
            Write-Host "[OK] $($f.Name)  ->  Collection\$fixedName" -ForegroundColor Green
        }
        $counts.Collection++
    } else {
        Write-Host "[SKIP] $fixedName already exists in Collection\" -ForegroundColor DarkYellow
    }
}

# ─────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────
Write-Host "`n========================================" -ForegroundColor White
Write-Host "  PASS 2 DONE — Summary" -ForegroundColor White
Write-Host "========================================" -ForegroundColor White
Write-Host "  .js junk deleted:    $($counts.Deleted)" -ForegroundColor Red
Write-Host "  JAV\                 $($counts.JAV) files" -ForegroundColor Cyan
Write-Host "  BBC - Interracial\   $($counts.BBC) files" -ForegroundColor Cyan
Write-Host "  Collection\          $($counts.Collection) files (encoding fixed)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor White

# Verify root is clean
Write-Host "Remaining files at root after cleanup:" -ForegroundColor Yellow
Get-ChildItem -LiteralPath $root -File | Select-Object Name | Format-Table -AutoSize
