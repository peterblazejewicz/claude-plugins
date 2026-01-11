@{
    # PSScriptAnalyzer settings for claude-plugins repository
    # See: https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer

    Severity = @('Error', 'Warning')

    ExcludeRules = @(
        # Write-Host is intentionally used for user-facing status messages
        # These messages need to be visible even when stdout is captured
        'PSAvoidUsingWriteHost',
        # Files use UTF-8 without BOM which is modern best practice
        # Emojis work fine without BOM in PowerShell 7.x
        'PSUseBOMForUnicodeEncodedFile'
    )

    Rules = @{
        # Enforce consistent indentation
        PSUseConsistentIndentation = @{
            Enable = $true
            IndentationSize = 4
            Kind = 'space'
        }

        # Enforce consistent whitespace
        PSUseConsistentWhitespace = @{
            Enable = $true
            CheckInnerBrace = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator = $true
            CheckPipe = $true
            CheckSeparator = $true
        }

        # Alignment checking disabled - too strict for multi-line hashtables
        # and the upstream scripts don't follow this convention
        PSAlignAssignmentStatement = @{
            Enable = $false
        }
    }
}
