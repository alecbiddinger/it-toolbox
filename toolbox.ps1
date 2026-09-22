<#
.SYNOPSIS
Launch the toolbox with a persistent work directory.
.EXAMPLE
.\toolbox.ps1
.EXAMPLE
.\toolbox.ps1 -Image it-toolbox:1.0.0 -Command @('dns-check.sh', 'example.com')
#>
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$Image = 'it-toolbox:latest',
    [ValidateNotNullOrEmpty()]
    [string]$WorkDirectory = (Join-Path $PSScriptRoot 'work'),
    [string[]]$Command = @(),
    [switch]$NoTty
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker was not found. Install Docker and ensure its CLI is on PATH.'
}
# The default follows this script; custom relative paths follow the caller.
$workPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($WorkDirectory)
if ($workPath.Contains(',') -or $workPath.Contains('"')) {
    throw 'The work directory cannot contain a comma or double quote (Docker mount syntax).'
}
if (-not (Test-Path -LiteralPath $workPath)) {
    New-Item -ItemType Directory -Path $workPath -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $workPath -PathType Container)) {
    throw 'WorkDirectory must be a directory.'
}
$workPath = (Get-Item -LiteralPath $workPath).FullName
$dockerArgs = @('run', '--rm')
if ($Command.Count -eq 0 -and -not $NoTty) { $dockerArgs += '-it' }
$dockerArgs += @('--mount', "type=bind,source=$workPath,target=/work", $Image)
$dockerArgs += $Command
& docker @dockerArgs
exit $LASTEXITCODE
