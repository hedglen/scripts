#Requires -Version 5.1
<#
.SYNOPSIS
  Two-phase rename: cleaned title + optional resolution tag (no numeric prefix). mp4/srt/md (optional .ts).
.EXAMPLE
  .\media-rename-downloads.ps1
  .\media-rename-downloads.ps1 -Root 'C:\Users\rjh\x' -Recurse -IncludeTs
  .\media-rename-downloads.ps1 -Root 'C:\Users\rjh\x' -Recurse -IncludeTs -StripOrdinalOnly
  .\media-rename-downloads.ps1 -WhatIf
#>
param(
    [string]$Root = 'D:\Media\Downloads',
    [switch]$WhatIf,
    [switch]$Recurse,
    [switch]$IncludeTs,
    # Only remove leading "01 - " / "01 – " etc.; do not re-clean titles (fast fix for leftover ordinals).
    [switch]$StripOrdinalOnly
)

$ErrorActionPreference = 'Stop'
$mediaExt = [string[]]@('.mp4', '.srt', '.md')
if ($IncludeTs) { $mediaExt = $mediaExt + '.ts' }

$videoExt = @('.mp4', '.mkv', '.webm', '.avi', '.mov', '.ts')

function Get-VideoResolutionTag {
    param([string]$BaseName, [string]$Ext)
    if ($videoExt -notcontains $Ext.ToLowerInvariant()) { return '' }
    # ASCII hyphen or en/em dash before resolution token
    if ($BaseName -match '(?i)(?:\s*[\u2013\u2014-]\s*|\s+-\s+|[_\s])(2160p|1080p|720p|480p|4k)\s*$') {
        return ' – ' + $Matches[1].ToLowerInvariant()
    }
    return ''
}

function Remove-ResolutionSuffix {
    param([string]$s)
    $s = $s -replace '(?i)\s*[\u2013\u2014-]\s*(2160p|1080p|720p|480p|4k)\s*$', ''
    $s = $s -replace '(?i)\s+-\s+(2160p|1080p|720p|480p|4k)\s*$', ''
    $s = $s -replace '(?i)[_\s](2160p|1080p|720p|480p|4k)\s*$', ''
    return $s.TrimEnd()
}

function Strip-LeadingIndex {
    param([string]$base)
    # ASCII: "01 - Title" (space around hyphen)
    if ($base -match '^\d{1,4}\s+-\s+(.+)$') {
        return $Matches[1].Trim()
    }
    # En dash, em dash, minus sign, or hyphen-minus (single char between spaces optional)
    if ($base -match '^\d{1,4}\s*[\u2013\u2014\u2212-]\s*(.+)$') {
        return $Matches[1].Trim()
    }
    return $base
}

function Get-MediaGroupKey {
    param([string]$baseName)
    $s = Strip-LeadingIndex $baseName
    if ($s -match '^([A-Z]{2,}-\d+)\s+-\s+') { return $Matches[1] }
    if ($s -match '^([A-Z]{2,}-\d+)$') { return $Matches[1] }
    return $s
}

function Select-PrimaryBaseName {
    param([object[]]$GroupFiles)
    $v = @($GroupFiles | Where-Object { $videoExt -contains $_.Extension.ToLowerInvariant() } | Sort-Object Name)
    if ($v.Count -gt 0) { return $v[0].BaseName }
    return (@($GroupFiles | Sort-Object Name | Select-Object -First 1)).BaseName
}

function Clean-MediaStem {
    param([string]$base)
    $s = Strip-LeadingIndex $base
    $s = $s -replace '_xh[A-Za-z0-9]+$', ''
    $s = $s -replace '_\d{5,}$', ''
    $s = Remove-ResolutionSuffix $s
    $s = $s -replace '(?i)^spankbang\s*[-–—]\s*', ''
    $s = $s -replace '\+', ' '
    $s = $s -replace '_', ' '
    $s = $s -replace ' \(1\)$', ''
    $s = $s -replace '\s+', ' '
    $s = $s.Trim()

    foreach ($sep in @(' – ', ' - ')) {
        $i = $s.IndexOf($sep, [System.StringComparison]::Ordinal)
        if ($i -lt 0) { continue }
        $first = $s.Substring(0, $i).Trim()
        $rest = $s.Substring($i + $sep.Length).Trim()
        if ($first -match '^\d+$') { break }
        $noSpacesInFirst = ($first -notmatch '\s')
        $startsLower = ($first.Length -gt 0 -and [char]::IsLower($first, 0))
        $hasDigit = ($first -match '\d')
        if ($noSpacesInFirst -and ($startsLower -or $hasDigit)) {
            $s = "$rest ($first)"
        }
        break
    }
    $s = $s -replace '\s+', ' '
    return $s.Trim()
}

function Invoke-OrdinalStripDirectory {
    param(
        [string]$Dir,
        [switch]$DirWhatIf,
        [int]$PreviewFirst = 8
    )

    $files = @(Get-ChildItem -LiteralPath $Dir -File -ErrorAction SilentlyContinue | Where-Object {
            $mediaExt -contains $_.Extension.ToLowerInvariant()
        })
    if ($files.Count -eq 0) { return 0 }

    $planned = [System.Collections.Generic.List[object]]::new()
    foreach ($f in $files) {
        $nb = Strip-LeadingIndex $f.BaseName
        if ($nb -ceq $f.BaseName) { continue }
        $final = $nb + $f.Extension
        if ([string]::Equals($final, $f.Name, [StringComparison]::OrdinalIgnoreCase)) { continue }
        $planned.Add([pscustomobject]@{ FullName = $f.FullName; Extension = $f.Extension; OldName = $f.Name; FinalName = $final })
    }

    $blocked = @{}
    foreach ($x in @(Get-ChildItem -LiteralPath $Dir -File -ErrorAction SilentlyContinue)) {
        $blocked[$x.Name.ToLowerInvariant()] = $true
    }
    foreach ($p in $planned) {
        $blocked.Remove($p.OldName.ToLowerInvariant())
    }

    $seen = @{}
    $finalList = [System.Collections.Generic.List[object]]::new()
    foreach ($p in $planned) {
        $name = $p.FinalName
        $baseFinal = [System.IO.Path]::GetFileNameWithoutExtension($name)
        $ext = [System.IO.Path]::GetExtension($name)
        $key = $name.ToLowerInvariant()
        if (-not $seen.ContainsKey($key) -and -not $blocked.ContainsKey($key)) {
            $seen[$key] = 1
            $p | Add-Member -NotePropertyName AdjustedFinal -NotePropertyValue $name -Force
            $finalList.Add($p) | Out-Null
            continue
        }
        $n = 2
        while ($true) {
            $try = "$baseFinal ($n)$ext"
            $tk = $try.ToLowerInvariant()
            if (-not $seen.ContainsKey($tk) -and -not $blocked.ContainsKey($tk)) {
                $seen[$tk] = 1
                $p | Add-Member -NotePropertyName AdjustedFinal -NotePropertyValue $try -Force
                $finalList.Add($p) | Out-Null
                break
            }
            $n++
        }
    }

    if ($finalList.Count -eq 0) { return 0 }

    Write-Host ""
    Write-Host $Dir
    Write-Host ("  Strip ordinal prefix: {0} file(s)" -f $finalList.Count)
    $show = [Math]::Min($PreviewFirst, $finalList.Count)
    for ($i = 0; $i -lt $show; $i++) {
        $p = $finalList[$i]
        Write-Host ("    {0} -> {1}" -f $p.OldName, $p.AdjustedFinal)
    }
    if ($finalList.Count -gt $show) { Write-Host "    ..." }

    if ($DirWhatIf) { return $finalList.Count }

    $tmp = 0
    $map = @()
    foreach ($p in $finalList) {
        $tmp++
        $tname = "__tmp_{0:D4}{1}" -f $tmp, $p.Extension
        $tpath = Join-Path $Dir $tname
        Rename-Item -LiteralPath $p.FullName -NewName $tname
        $map += [pscustomobject]@{ Temp = $tpath; Final = (Join-Path $Dir $p.AdjustedFinal) }
    }
    foreach ($m in $map) {
        Rename-Item -LiteralPath $m.Temp -NewName ([System.IO.Path]::GetFileName($m.Final))
    }
    return $finalList.Count
}

function Invoke-MediaRenameDirectory {
    param(
        [string]$Dir,
        [switch]$DirWhatIf,
        [int]$PreviewFirst = 8
    )

    $files = @(Get-ChildItem -LiteralPath $Dir -File -ErrorAction SilentlyContinue | Where-Object {
            $mediaExt -contains $_.Extension.ToLowerInvariant()
        })
    if ($files.Count -eq 0) { return 0 }

    $groups = $files | Group-Object { Get-MediaGroupKey $_.BaseName } | Sort-Object {
            $rep = Select-PrimaryBaseName $_.Group
            Clean-MediaStem $rep
        }, Name

    $planned = [System.Collections.Generic.List[object]]::new()
    foreach ($g in $groups) {
        $primaryBase = Select-PrimaryBaseName $g.Group
        $stem = Clean-MediaStem $primaryBase
        if ([string]::IsNullOrWhiteSpace($stem)) { $stem = 'untitled' }
        foreach ($f in $g.Group) {
            $ext = $f.Extension.ToLowerInvariant()
            $res = Get-VideoResolutionTag -BaseName $f.BaseName -Ext $ext
            $final = ('{0}{1}{2}' -f $stem, $res, $ext)
            if ([string]::Equals($final, $f.Name, [StringComparison]::OrdinalIgnoreCase)) { continue }
            $planned.Add([pscustomobject]@{ FullName = $f.FullName; Extension = $f.Extension; OldName = $f.Name; FinalName = $final })
        }
    }

    $blocked = @{}
    foreach ($x in @(Get-ChildItem -LiteralPath $Dir -File -ErrorAction SilentlyContinue)) {
        $blocked[$x.Name.ToLowerInvariant()] = $true
    }
    foreach ($p in $planned) {
        $blocked.Remove($p.OldName.ToLowerInvariant())
    }

    $seen = @{}
    $finalList = [System.Collections.Generic.List[object]]::new()
    foreach ($p in $planned) {
        $name = $p.FinalName
        $baseFinal = [System.IO.Path]::GetFileNameWithoutExtension($name)
        $ext = [System.IO.Path]::GetExtension($name)
        $key = $name.ToLowerInvariant()
        if (-not $seen.ContainsKey($key) -and -not $blocked.ContainsKey($key)) {
            $seen[$key] = 1
            $p | Add-Member -NotePropertyName AdjustedFinal -NotePropertyValue $name -Force
            $finalList.Add($p) | Out-Null
            continue
        }
        $n = 2
        while ($true) {
            $try = "$baseFinal ($n)$ext"
            $tk = $try.ToLowerInvariant()
            if (-not $seen.ContainsKey($tk) -and -not $blocked.ContainsKey($tk)) {
                $seen[$tk] = 1
                $p | Add-Member -NotePropertyName AdjustedFinal -NotePropertyValue $try -Force
                $finalList.Add($p) | Out-Null
                break
            }
            $n++
        }
    }

    if ($finalList.Count -eq 0) { return 0 }

    Write-Host ""
    Write-Host $Dir
    Write-Host ("  Rename: {0} (groups: {1}, files: {2})" -f $finalList.Count, $groups.Count, $files.Count)
    $show = [Math]::Min($PreviewFirst, $finalList.Count)
    for ($i = 0; $i -lt $show; $i++) {
        $p = $finalList[$i]
        Write-Host ("    {0} -> {1}" -f $p.OldName, $p.AdjustedFinal)
    }
    if ($finalList.Count -gt $show) { Write-Host "    ..." }

    if ($DirWhatIf) { return $finalList.Count }

    $tmp = 0
    $map = @()
    foreach ($p in $finalList) {
        $tmp++
        $tname = "__tmp_{0:D4}{1}" -f $tmp, $p.Extension
        $tpath = Join-Path $Dir $tname
        Rename-Item -LiteralPath $p.FullName -NewName $tname
        $map += [pscustomobject]@{ Temp = $tpath; Final = (Join-Path $Dir $p.AdjustedFinal) }
    }
    foreach ($m in $map) {
        Rename-Item -LiteralPath $m.Temp -NewName ([System.IO.Path]::GetFileName($m.Final))
    }
    return $finalList.Count
}

# --- main ---
if (-not (Test-Path -LiteralPath $Root)) {
    Write-Error "Root path does not exist: $Root"
    exit 1
}

if ($StripOrdinalOnly) {
    if ($Recurse) {
        $all = @(Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction Stop | Where-Object {
                $mediaExt -contains $_.Extension.ToLowerInvariant()
            })
        if ($all.Count -eq 0) {
            Write-Host "No matching files under $Root"
            exit 0
        }
        $dirs = $all | Select-Object -ExpandProperty DirectoryName -Unique | Sort-Object
        foreach ($d in $dirs) {
            $null = Invoke-OrdinalStripDirectory -Dir $d -DirWhatIf:$WhatIf
        }
        Write-Host ""
        if ($WhatIf) { Write-Host "WhatIf: no files renamed." }
        else { Write-Host ("Done. Stripped ordinals in {0} folder(s)." -f $dirs.Count) }
    }
    else {
        $n = Invoke-OrdinalStripDirectory -Dir $Root -DirWhatIf:$WhatIf -PreviewFirst 25
        if ($n -eq 0) { Write-Host "No ordinal prefixes to strip under $Root" }
        elseif ($WhatIf) { Write-Host "WhatIf: no files renamed." }
        else { Write-Host "Done." }
    }
    exit 0
}

if ($Recurse) {
    $all = @(Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction Stop | Where-Object {
            $mediaExt -contains $_.Extension.ToLowerInvariant()
        })
    if ($all.Count -eq 0) {
        Write-Host "No matching files under $Root"
        exit 0
    }
    $dirs = $all | Select-Object -ExpandProperty DirectoryName -Unique | Sort-Object
    $total = 0
    foreach ($d in $dirs) {
        $total += Invoke-MediaRenameDirectory -Dir $d -DirWhatIf:$WhatIf
    }
    Write-Host ""
    if ($WhatIf) {
        Write-Host "WhatIf: no files renamed."
    }
    else {
        Write-Host ("Done. Renamed across {0} folders (operations above)." -f $dirs.Count)
    }
    exit 0
}

$n = Invoke-MediaRenameDirectory -Dir $Root -DirWhatIf:$WhatIf -PreviewFirst 25
if ($n -eq 0) {
    Write-Host "No renames needed under $Root"
    exit 0
}
if ($WhatIf) {
    Write-Host "WhatIf: no files renamed."
}
else {
    Write-Host "Done."
}
