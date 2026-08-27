#requires -Version 7.4

BeforeAll {
    $script:PluginRoot = Split-Path -Parent $PSScriptRoot
    $script:RepositoryRoot = Split-Path -Parent $script:PluginRoot
}

Describe "PowerShell package" {
    It "contains the required operational scripts" -ForEach @(
        "Install-MultiMouseControl.ps1",
        "Configure-MouseMuxMcp.ps1",
        "Force-Stop-MouseMux.ps1",
        "Verify-MultiMouseControl.ps1",
        "Start-AgentSandbox.ps1",
        "Discover-InputDevices.ps1",
        "Uninstall-MultiMouseControl.ps1"
    ) {
        Join-Path $script:PluginRoot "scripts\$_" | Should -Exist
    }

    It "parses every PowerShell source file without syntax errors" {
        $files = Get-ChildItem -Path $script:PluginRoot -Recurse -File |
            Where-Object { $_.Extension -in @(".ps1", ".psm1") }

        $files.Count | Should -BeGreaterThan 0
        foreach ($file in $files) {
            $tokens = $null
            $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile(
                $file.FullName,
                [ref]$tokens,
                [ref]$errors
            )
            $errors | Should -BeNullOrEmpty -Because $file.FullName
        }
    }

    It "pins the currently published MouseMux V3 installer over HTTPS" {
        $installerScript = Get-Content -Raw (Join-Path $script:PluginRoot "scripts\Install-MultiMouseControl.ps1")
        $installerScript | Should -Match 'https://files\.mousemux\.com/files/setup/mousemux-v3-setup-3\.0\.19\.exe'
    }

    It "does not register a custom shortcut on the vendor emergency hotkey" {
        $installerScript = Get-Content -Raw (Join-Path $script:PluginRoot "scripts\Install-MultiMouseControl.ps1")
        $installerScript | Should -Not -Match 'Hotkey\s*=\s*["'']CTRL\+ALT\+F12["'']'
    }

    It "does not create a highest-privilege task from user-writable files" {
        $installerScript = Get-Content -Raw (Join-Path $script:PluginRoot "scripts\Install-MultiMouseControl.ps1")
        $installerScript | Should -Not -Match 'Register-ScheduledTask'
        $installerScript | Should -Not -Match 'RunLevel\s*=\s*["'']Highest["'']'
        $installerScript | Should -Not -Match 'schtasks\.exe'
    }

    It "creates a current-user force-stop shortcut" {
        $installerScript = Get-Content -Raw (Join-Path $script:PluginRoot "scripts\Install-MultiMouseControl.ps1")
        $installerScript | Should -Match 'Force-Stop-MouseMux\.ps1'
        $installerScript | Should -Match 'powershell\.exe'
    }

    It "uses canonical path containment instead of a string-prefix check" {
        $installerScript = Get-Content -Raw (Join-Path $script:PluginRoot "scripts\Install-MultiMouseControl.ps1")
        $uninstallerScript = Get-Content -Raw (Join-Path $script:PluginRoot "scripts\Uninstall-MultiMouseControl.ps1")
        $installerScript | Should -Match 'Test-MmcPathWithinRoot'
        $uninstallerScript | Should -Match 'Test-MmcPathWithinRoot'
    }

    It "requires strict process identity before force-stopping a port owner" {
        $forceStop = Get-Content -Raw (Join-Path $script:PluginRoot "scripts\Force-Stop-MouseMux.ps1")
        $forceStop | Should -Match 'Test-MouseMuxProcessIdentity'
        $forceStop | Should -Not -Match 'Stop-Process\s+-Id\s+\$listenerPid\s+-Force\s*$'
    }
}

Describe "Cursor plugin definition" {
    It "has a valid focused manifest and all declared component paths exist" {
        $manifestPath = Join-Path $script:PluginRoot ".cursor-plugin\plugin.json"
        $manifestPath | Should -Exist
        $manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json -AsHashtable

        $manifest.name | Should -Be "multi-mouse-control"
        $manifest.version | Should -Match '^\d+\.\d+\.\d+$'
        $manifest.skills | Should -Be "./skills/"
        $manifest.agents | Should -Be "./agents/"
        Join-Path $script:PluginRoot "skills" | Should -Exist
        Join-Path $script:PluginRoot "agents" | Should -Exist
    }

    It "is wired into the marketplace" {
        $marketplacePath = Join-Path $script:RepositoryRoot ".cursor-plugin\marketplace.json"
        $marketplace = Get-Content -Raw $marketplacePath | ConvertFrom-Json
        $entry = @($marketplace.plugins | Where-Object name -eq "multi-mouse-control")
        $entry.Count | Should -Be 1
        $entry[0].source | Should -Be "multi-mouse-control"
    }
}

Describe "Safety documentation" {
    It "documents MouseMux built-in emergency exit and the separate non-elevated fallback" {
        $readme = Get-Content -Raw (Join-Path $script:PluginRoot "README.md")
        $readme | Should -Match 'Ctrl\+Alt\+F12'
        $readme | Should -Match 'FORCE STOP - MouseMux'
        $readme | Should -Match 'non-elevated'
        $readme | Should -Not -Match 'Elevated fallback'
    }

    It "states that window locking is not a Windows security boundary" {
        $security = Get-Content -Raw (Join-Path $script:PluginRoot "docs\SECURITY.md")
        $security | Should -Match 'not a Windows security boundary'
    }
}
