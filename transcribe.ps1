# transcribe.ps1 — wrapper for transcribe.py
# Usage: .\transcribe.ps1 "path\to\video.ts" [-Model large-v3] [-Language en]

param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Video,

    [ValidateSet("tiny", "base", "small", "medium", "large-v2", "large-v3")]
    [string]$Model = "large-v3",

    [string]$Language
)

$python = "C:\Users\rjh\workstation\tools\transcribe-env\Scripts\python.exe"
$script = "$PSScriptRoot\transcribe.py"

$args = @($script, $Video, "--model", $Model)
if ($Language) { $args += @("--language", $Language) }

& $python @args
