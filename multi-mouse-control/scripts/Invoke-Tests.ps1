#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$pluginRoot = Split-Path -Parent $PSScriptRoot
$testPath = Join-Path $pluginRoot 'tests'

$pester = Get-Module Pester -ListAvailable |
    Where-Object { $_.Version -ge [version]'5.7.1' -and $_.Version.Major -eq 5 } |
    Sort-Object Version -Descending |
    Select-Object -First 1

if ($null -eq $pester) {
    throw 'Pester 5.7.1 or a newer 5.x release is required. Run: Install-Module Pester -RequiredVersion 5.7.1 -Scope CurrentUser'
}

Import-Module $pester.Path -Force
$configuration = New-PesterConfiguration
$configuration.Run.Path = $testPath
$configuration.Run.Exit = $true
$configuration.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $configuration
