#requires -Version 7.4

BeforeAll {
    $script:PluginRoot = Split-Path -Parent $PSScriptRoot
    $modulePath = Join-Path $script:PluginRoot "scripts\MultiMouseControl.Core.psm1"
    Import-Module $modulePath -Force -ErrorAction Stop
}

Describe "Resolve-MmcMcpUri" {
    It "accepts the documented loopback endpoint" {
        $result = Resolve-MmcMcpUri -Url "http://127.0.0.1:41760/mcp"
        $result.AbsoluteUri | Should -Be "http://127.0.0.1:41760/mcp"
    }

    It "accepts localhost while preserving the exact URL" {
        $result = Resolve-MmcMcpUri -Url "http://localhost:41760/"
        $result.AbsoluteUri | Should -Be "http://localhost:41760/"
    }

    It "rejects unsafe or unexpected endpoints" -ForEach @(
        @{ Url = "https://127.0.0.1:41760/mcp"; Reason = "scheme" }
        @{ Url = "http://192.168.1.25:41760/mcp"; Reason = "host" }
        @{ Url = "http://127.0.0.1:41761/mcp"; Reason = "port" }
        @{ Url = "http://user:pass@127.0.0.1:41760/mcp"; Reason = "credentials" }
        @{ Url = "http://127.0.0.1:41760/mcp?token=secret"; Reason = "query" }
        @{ Url = "http://127.0.0.1:41760/mcp#fragment"; Reason = "fragment" }
        @{ Url = "not-a-uri"; Reason = "absolute URI" }
    ) {
        { Resolve-MmcMcpUri -Url $Url } | Should -Throw
    }
}

Describe "Set-CodexMouseMuxBlock" {
    It "adds one current Codex MCP block to an empty configuration" {
        $updated = Set-CodexMouseMuxBlock -Content "" -Url "http://127.0.0.1:41760/mcp"

        $updated | Should -Match '(?m)^\[mcp_servers\.mousemux\]$'
        $updated | Should -Match '(?m)^url = "http://127\.0\.0\.1:41760/mcp"$'
        $updated | Should -Match '(?m)^enabled = true$'
        $updated | Should -Match '(?m)^required = false$'
        $updated | Should -Match '(?m)^default_tools_approval_mode = "prompt"$'
    }

    It "preserves unrelated tables and replaces the complete mousemux namespace" {
        $existing = @'
model = "gpt-5.6-codex"

[mcp_servers.mousemux]
url = "http://127.0.0.1:9999/old"

[mcp_servers.mousemux.tools.move]
approval_mode = "auto"

[mcp_servers.other]
url = "https://example.invalid/mcp"
'@

        $updated = Set-CodexMouseMuxBlock -Content $existing -Url "http://127.0.0.1:41760/mcp"

        ([regex]::Matches($updated, '(?m)^\[mcp_servers\.mousemux\]$')).Count | Should -Be 1
        $updated | Should -Not -Match '9999'
        $updated | Should -Not -Match '\[mcp_servers\.mousemux\.tools\.move\]'
        $updated | Should -Match '\[mcp_servers\.other\]'
        $updated | Should -Match 'model = "gpt-5\.6-codex"'
    }

    It "is idempotent" {
        $once = Set-CodexMouseMuxBlock -Content "" -Url "http://127.0.0.1:41760/mcp"
        $twice = Set-CodexMouseMuxBlock -Content $once -Url "http://127.0.0.1:41760/mcp"
        $twice | Should -BeExactly $once
    }

    It "writes a TOML enabled_tools allowlist when supplied" {
        $updated = Set-CodexMouseMuxBlock `
            -Content "" `
            -Url "http://127.0.0.1:41760/mcp" `
            -EnabledTool @("graph_read", "virtual_user_type_text")

        $updated | Should -Match '(?m)^enabled_tools = \["graph_read", "virtual_user_type_text"\]$'
    }
}

Describe "Remove-CodexMouseMuxBlock" {
    It "removes the server table and all of its subtables without touching another server" {
        $existing = @'
[mcp_servers.mousemux]
url = "http://127.0.0.1:41760/mcp"

[mcp_servers.mousemux.tools.type]
approval_mode = "prompt"

[mcp_servers.other]
url = "https://example.invalid/mcp"
'@

        $updated = Remove-CodexMouseMuxBlock -Content $existing

        $updated | Should -Not -Match 'mcp_servers\.mousemux'
        $updated | Should -Match 'mcp_servers\.other'
    }
}

Describe "Test-MouseMuxProcessIdentity" {
    It "accepts a MouseMux executable under a MouseMux installation directory" {
        Test-MouseMuxProcessIdentity `
            -Name "MouseMux.exe" `
            -ExecutablePath "C:\Program Files\MouseMux V3\MouseMux.exe" `
            -CommandLine '"C:\Program Files\MouseMux V3\MouseMux.exe"' | Should -BeTrue
    }

    It "accepts a known exact MouseMux process name when Windows withholds the path" {
        Test-MouseMuxProcessIdentity -Name "MouseMuxAppHost.exe" -ExecutablePath $null -CommandLine $null | Should -BeTrue
    }

    It "rejects an unrelated process even when its command line mentions MouseMux" {
        Test-MouseMuxProcessIdentity `
            -Name "python.exe" `
            -ExecutablePath "C:\Python\python.exe" `
            -CommandLine "python C:\Users\Troon\MouseMux-helper.py" | Should -BeFalse
    }

    It "rejects a generic WebView process" {
        Test-MouseMuxProcessIdentity `
            -Name "msedgewebview2.exe" `
            -ExecutablePath "C:\Program Files (x86)\Microsoft\EdgeWebView\Application\msedgewebview2.exe" `
            -CommandLine "--embedded-browser-webview=1" | Should -BeFalse
    }
}
