Set-StrictMode -Version Latest

function Resolve-MmcMcpUri {
    [CmdletBinding()]
    [OutputType([System.Uri])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Url
    )

    $uri = $null
    if (-not [System.Uri]::TryCreate($Url, [System.UriKind]::Absolute, [ref]$uri)) {
        throw "MouseMux MCP URL must be an absolute URI."
    }

    if ($uri.Scheme -ne [System.Uri]::UriSchemeHttp) {
        throw "MouseMux MCP URL must use http because the endpoint is local-only."
    }

    if ($uri.Host -notin @('127.0.0.1', 'localhost', '::1')) {
        throw "MouseMux MCP URL must use 127.0.0.1, localhost, or ::1."
    }

    if ($uri.Port -ne 41760) {
        throw "MouseMux MCP URL must use port 41760."
    }

    if (-not [string]::IsNullOrEmpty($uri.UserInfo)) {
        throw "MouseMux MCP URL must not contain credentials."
    }

    if (-not [string]::IsNullOrEmpty($uri.Query)) {
        throw "MouseMux MCP URL must not contain a query string."
    }

    if (-not [string]::IsNullOrEmpty($uri.Fragment)) {
        throw "MouseMux MCP URL must not contain a fragment."
    }

    if ($uri.AbsolutePath.Contains('..') -or $uri.AbsolutePath.Contains('\')) {
        throw "MouseMux MCP URL contains an unsafe path."
    }

    return $uri
}

function Remove-CodexMouseMuxBlock {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()]
        [string]$Content = ''
    )

    $normalized = $Content -replace "`r`n?", "`n"
    $lines = $normalized -split "`n"
    $result = [System.Collections.Generic.List[string]]::new()
    $skipNamespace = $false

    foreach ($line in $lines) {
        if ($line -match '^\s*\[\s*(?<table>[^\]]+)\s*\]\s*(?:#.*)?$') {
            $table = $Matches.table.Trim()
            if ($table -eq 'mcp_servers.mousemux' -or $table.StartsWith('mcp_servers.mousemux.', [System.StringComparison]::Ordinal)) {
                $skipNamespace = $true
                continue
            }

            $skipNamespace = $false
        }

        if (-not $skipNamespace) {
            $result.Add($line)
        }
    }

    $output = [string]::Join("`n", $result)
    $output = [regex]::Replace($output, "(`n[ \t]*){3,}", "`n`n")
    return $output.TrimEnd()
}

function Set-CodexMouseMuxBlock {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()]
        [string]$Content = '',

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,

        [string[]]$EnabledTool
    )

    $uri = Resolve-MmcMcpUri -Url $Url
    $escapedUrl = $uri.AbsoluteUri.Replace('\', '\\').Replace('"', '\"')

    $block = [System.Collections.Generic.List[string]]::new()
    $block.Add('[mcp_servers.mousemux]')
    $block.Add("url = `"$escapedUrl`"")
    $block.Add('enabled = true')
    $block.Add('required = false')
    $block.Add('startup_timeout_sec = 10')
    $block.Add('tool_timeout_sec = 60')
    $block.Add('default_tools_approval_mode = "prompt"')

    if ($null -ne $EnabledTool -and $EnabledTool.Count -gt 0) {
        $toolValues = foreach ($tool in $EnabledTool) {
            if ([string]::IsNullOrWhiteSpace($tool)) {
                continue
            }

            $escapedTool = $tool.Replace('\', '\\').Replace('"', '\"')
            '"{0}"' -f $escapedTool
        }

        if ($toolValues.Count -gt 0) {
            $block.Add('enabled_tools = [{0}]' -f ([string]::Join(', ', $toolValues)))
        }
    }

    $baseContent = Remove-CodexMouseMuxBlock -Content $Content
    $blockText = [string]::Join("`n", $block)

    if ([string]::IsNullOrWhiteSpace($baseContent)) {
        return "$blockText`n"
    }

    return "$($baseContent.TrimEnd())`n`n$blockText`n"
}

function Test-MouseMuxProcessIdentity {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [AllowNull()]
        [string]$ExecutablePath,

        [AllowNull()]
        [string]$CommandLine
    )

    $knownNames = @(
        'MouseMux.exe',
        'MouseMuxAppHost.exe',
        'MouseMuxHost.exe',
        'MouseMux.Service.exe',
        'MouseMuxService.exe',
        'MouseMux.InputMapper.exe',
        'MouseMuxInputMapper.exe'
    )

    $normalizedName = [System.IO.Path]::GetFileName($Name)
    if ($normalizedName -notin $knownNames) {
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($ExecutablePath)) {
        return $true
    }

    $pathFileName = [System.IO.Path]::GetFileName($ExecutablePath)
    if ($pathFileName -ne $normalizedName) {
        return $false
    }

    $pathSegments = $ExecutablePath -split '[\\/]'
    $hasMouseMuxDirectory = $false
    foreach ($segment in $pathSegments) {
        if ($segment -match '(?i)^MouseMux(?:\s+V?3)?$' -or $segment -match '(?i)^MouseMux[ ._-]') {
            $hasMouseMuxDirectory = $true
            break
        }
    }

    if ($hasMouseMuxDirectory) {
        return $true
    }

    if (-not [string]::IsNullOrWhiteSpace($CommandLine)) {
        $quotedExecutable = [regex]::Escape($ExecutablePath)
        if ($CommandLine -match $quotedExecutable -and $CommandLine -match '(?i)MouseMux') {
            return $true
        }
    }

    return $false
}

Export-ModuleMember -Function @(
    'Resolve-MmcMcpUri',
    'Remove-CodexMouseMuxBlock',
    'Set-CodexMouseMuxBlock',
    'Test-MouseMuxProcessIdentity'
)
