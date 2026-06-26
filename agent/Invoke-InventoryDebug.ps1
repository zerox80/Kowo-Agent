#Requires -Version 5.1
<#
.SYNOPSIS
    Debug-Wrapper fuer den HardView Inventar-Agent unter Scheduled Task/GPO.

.DESCRIPTION
    Wird temporaer statt Invoke-Inventory.ps1 als Task-Aktion verwendet. Der Wrapper
    laeuft im selben Kontext wie der GPO-Task (typisch SYSTEM), ruft den eigentlichen
    Agent auf und schreibt stdout/stderr/Verbose sowie Terminierungsfehler lokal nach
    %ProgramData%\HardView\agent\task-debug.log.

    Nach der Fehlersuche wieder auf Invoke-Inventory.ps1 zurueckstellen.

.EXAMPLE
    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "\\YOUR_DOMAIN.local\NETLOGON\HardView\Invoke-InventoryDebug.ps1" -OutputDir "\\FILESERVER\Inventory$\incoming"
#>
[CmdletBinding()]
param(
    [string] $ScriptPath,
    [string] $OutputDir = '\\FILESERVER\Inventory$\incoming',
    [string] $LogDir = (Join-Path $env:ProgramData 'HardView\agent'),
    [string] $LogName = 'task-debug.log',
    [switch] $Local,
    [switch] $PassThru
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'
$DebugPreference = 'Continue'
Set-StrictMode -Version 2.0

$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptRoot) -and $MyInvocation.MyCommand.Path) {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
    $ScriptPath = Join-Path $scriptRoot 'Invoke-Inventory.ps1'
}

function Write-TaskDebugLog {
    param([AllowNull()] $Value)

    try {
        if (-not (Test-Path -LiteralPath $LogDir)) {
            New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
        }

        $logPath = Join-Path $LogDir $LogName
        if ((Test-Path -LiteralPath $logPath) -and ((Get-Item -LiteralPath $logPath).Length -gt 1MB)) {
            Move-Item -LiteralPath $logPath -Destination (Join-Path $LogDir 'task-debug.1.log') -Force
        }

        $text = if ($null -eq $Value) { '<null>' } else { [string] $Value }
        Add-Content -LiteralPath $logPath -Value $text -Encoding UTF8
    } catch {
        # Logging must never hide the original task failure.
    }
}

function Test-PathForLog {
    param([string] $Path)

    try {
        return [string](Test-Path -LiteralPath $Path)
    } catch {
        return ('ERROR: {0}' -f $_.Exception.Message)
    }
}

try {
    Write-TaskDebugLog ('=== HardView inventory task debug {0} ===' -f (Get-Date).ToString('o'))
    Write-TaskDebugLog ('Identity       : {0}' -f [System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
    Write-TaskDebugLog ('Computer       : {0}' -f $env:COMPUTERNAME)
    Write-TaskDebugLog ('UserName       : {0}\{1}' -f $env:USERDOMAIN, $env:USERNAME)
    Write-TaskDebugLog ('PSScriptRoot   : {0}' -f $scriptRoot)
    Write-TaskDebugLog ('WorkingDir     : {0}' -f (Get-Location).Path)
    Write-TaskDebugLog ('PSVersion      : {0}' -f $PSVersionTable.PSVersion)
    Write-TaskDebugLog ('ExecutionPolicy: {0}' -f (Get-ExecutionPolicy))
    Write-TaskDebugLog ('ScriptPath     : {0}' -f $ScriptPath)
    Write-TaskDebugLog ('Script exists  : {0}' -f (Test-PathForLog $ScriptPath))
    Write-TaskDebugLog ('OutputDir      : {0}' -f $OutputDir)
    Write-TaskDebugLog ('OutputDir test : {0}' -f (Test-PathForLog $OutputDir))

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        throw "Agent-Skript nicht gefunden oder nicht lesbar: $ScriptPath"
    }

    $agentArgs = @{
        OutputDir = $OutputDir
        Verbose = $true
    }
    if ($Local) { $agentArgs['Local'] = $true }
    if ($PassThru) { $agentArgs['PassThru'] = $true }

    & $ScriptPath @agentArgs *>&1 | ForEach-Object {
        Write-TaskDebugLog ([string] $_)
    }

    Write-TaskDebugLog 'ExitCode       : 0'
    exit 0
} catch {
    Write-TaskDebugLog ('ERROR          : {0}' -f $_.Exception.Message)
    Write-TaskDebugLog ($_ | Format-List * -Force | Out-String)
    if ($_.ScriptStackTrace) {
        Write-TaskDebugLog ([string] $_.ScriptStackTrace)
    }
    Write-TaskDebugLog 'ExitCode       : 1'
    exit 1
}
