# Contributing

## Coding Standards

### PowerShell Scripts
- Use approved verbs (`Get-`, `Set-`, `New-`, `Remove-`, `Invoke-`, `Test-`)
- Include comment-based help for all functions (`<# .SYNOPSIS .DESCRIPTION .PARAMETER .EXAMPLE #>`)
- Use `[CmdletBinding()]` and `[Parameter(Mandatory)]` decorators
- Handle errors with `try/catch`; use `-ErrorAction Stop` on critical operations
- Never hardcode credentials, tenant IDs, or secrets — use parameters or environment variables
- Output objects, not formatted text — let the caller decide display format
- Include a `WhatIf` parameter for any script with destructive operations

### Python Scripts (Chapter 12)
- Python 3.10+ required
- Use `python-dotenv` for environment variables; never hardcode API keys
- Type hints on all function signatures
- `try/except` with specific exception types
- Log to stdout (not file) so output is capturable in CI/CD

### JavaScript/Node.js Scripts (Chapter 9)
- Node.js 18+ required
- Use `async/await` (no callback patterns)
- Token caching required for any M2M flow — never request a new token per API call
- All secrets via environment variables

## Pull Request Process
1. Fork the repository and create a feature branch (`feature/chapter-N-description`)
2. Test your script against a non-production environment
3. Scrub all output for real credentials, tenant IDs, UPNs, and IP addresses before committing
4. Update the relevant chapter `README.md` if adding a new script
5. Open a PR with: what the script does, what permissions it requires, sample output

## Reporting Issues
- Open a GitHub Issue with: chapter number, script name, error message, PowerShell/Python version
- For security vulnerabilities in the scripts themselves: email directly rather than opening a public issue

## Environment Setup for Testing
```powershell
# Minimal test environment
# - Microsoft 365 E3 or E5 developer tenant (free at developer.microsoft.com)
# - Entra ID P2 trial (30 days free)
# - Auth0 free tier (Chapter 9 scripts)
# - Anthropic API key (Chapter 12 scripts — claude-haiku-4-5 is cheapest for testing)
```
