<#
.SYNOPSIS
Check launcher work paths, exit codes, and argument passing against a built image.
.EXAMPLE
./tests/launcher.ps1 -Image it-toolbox:1.0.0
#>
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$Image = 'it-toolbox:latest'
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$launcher = Join-Path $repoRoot 'toolbox.ps1'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('toolbox-test-' + [guid]::NewGuid())
$marker = 'launcher-test-' + [guid]::NewGuid() + '.txt'
$failures = 0
function Assert-Check([string]$Name, [bool]$Passed) {
    if ($Passed) { Write-Host "ok   $Name" } else { Write-Host "FAIL $Name"; $script:failures++ }
}

New-Item -ItemType Directory -Path $tempRoot | Out-Null
Push-Location -LiteralPath $tempRoot
try {
    & $launcher -Image $Image -Command @('bash', '-c', "echo default > /work/$marker")
    $defaultFile = Join-Path (Join-Path $repoRoot 'work') $marker
    Assert-Check 'default work directory follows the script' (
        (Get-Content -LiteralPath $defaultFile -ErrorAction SilentlyContinue) -eq 'default')
    Remove-Item -LiteralPath $defaultFile -ErrorAction SilentlyContinue

    & $launcher -Image $Image -WorkDirectory 'relative dir' -Command @('bash', '-c', 'echo relative > /work/out.txt')
    Assert-Check 'relative work path with a space follows the caller' (
        (Get-Content -LiteralPath (Join-Path $tempRoot 'relative dir/out.txt') -ErrorAction SilentlyContinue) -eq 'relative')

    & $launcher -Image $Image -WorkDirectory $tempRoot -Command @('bash', '-c', 'exit 7')
    Assert-Check 'container exit code propagates' ($LASTEXITCODE -eq 7)

    $message = ''
    try { & $launcher -Image $Image -WorkDirectory (Join-Path $tempRoot 'a,b') -Command @('true') }
    catch { $message = $_.Exception.Message }
    Assert-Check 'comma in work path is rejected' ($message -match 'comma')

    # Every argument must reach the container unchanged, including quotes and empties.
    $sent = @('printf "persistent\n"', '', 'two words', 'trailing\ slash\', 'a\"b', '"', 'plain')
    $json = & $launcher -Image $Image -WorkDirectory $tempRoot -Command (@('jq', '-cn', '$ARGS.positional', '--args') + $sent)
    $received = @($json | ConvertFrom-Json | ForEach-Object { $_ })
    $expected = ($sent | ForEach-Object { "[$_]" }) -join ''
    $actual = ($received | ForEach-Object { "[$_]" }) -join ''
    Assert-Check "arguments pass through unchanged (got $actual)" ($actual -ceq $expected)
}
finally {
    Pop-Location
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
if ($failures) { throw "$failures launcher check(s) failed." }
exit 0
