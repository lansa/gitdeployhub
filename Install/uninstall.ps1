<#
.SYNOPSIS

UnInstall GitDeployHub

This script presumes that the GitDeployHub git repo has been cloned into a directory of this form:
c:\inetpub\wwwroot_git\GitDeployHub. Though it should not make any difference

IIS is already enabled

This script is running as Administrator

This script is expected to be run as provided in the example below. An alternative is to run
this command first before the script may be executed
    powershell Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine

.EXAMPLE
powershell.exe -ExecutionPolicy Bypass .\install.ps1

to specify the web site name and port number
powershell.exe -ExecutionPolicy Bypass .\uninstall.ps1 -WebSiteName 'testgit'
#>

param (
    [Parameter(Mandatory=$true)]
        [string]
        $WebSiteName
)

function Log-Date 
{
    ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ssZ")
}

cmd /c exit 0    #Set $LASTEXITCODE

try {
    #Requires -RunAsAdministrator

    Import-Module WebAdministration

    $MyInvocation.MyCommand.Path
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $GitRepoRoot = Split-Path -Parent $ScriptDir

    Write-Output("$(Log-Date)")

    Write-Output ("WebSiteName: $WebSiteName")
        
    # Default install location is c:\inetpub\wwwroot_git
    # LANSA Path is c:\program files(x86)\mycompany\myapp\tools
    # If its the default path, call the website 'git'
    # If its the LANSA path, use 'myapp'

    $IsDefault = $false

    if ( [string]::IsNullOrWhiteSpace($WebSiteName) ) {
        $TempName = split-path -Parent $GitRepoRoot | split-path -Parent | split-path -Leaf
        if ( $TempName -eq 'inetpub') {
            $WebSiteName = 'git'
            $IsDefault = $true
        } else {
            $WebSiteName = $TempName
        }
    }

    Write-Output ("Web Site Name = $WebSiteName")
    $HubSite = Get-ChildItem iis:\Sites | Where-Object{$_.Name -eq $WebSiteName}
    if ( $HubSite -ne $null) {

        # Stop web site provided iis server is running
        $iis = get-wmiobject Win32_Service -Filter "name='w3svc'"
        if ( $iis -ne $null -and $iis.state -eq 'Running') {
            Stop-Website -name $WebSiteName
        }        
        
        Write-Output ("Delete a hub application in $WebSiteName web site")
        Remove-WebApplication -Name "Hub" -Site $WebSiteName
        
        # Delete the web site
        Remove-Website $WebSiteName

        # Remove App Pool
        Remove-WebAppPool -Name $WebSiteName        
    } else {
        Write-Output("Warning: web site does not exist")
    }
} catch {
    $e = $_.Exception
    $e|format-list -force
    
    Write-Output("Uninstallation failed")
    Write-Output("Raw LASTEXITCODE $LASTEXITCODE")  
    if ( (-not [string]::IsNullOrWhiteSpace($LASTEXITCODE)) -and ($LASTEXITCODE -ne 0)) {
        $ExitCode = $LASTEXITCODE
        Write-Output("ExitCode set to LASTEXITCODE $ExitCode")        
    } else {
        $ExitCode =  $e.HResult
        Write-Output("ExitCode set to HResult $ExitCode")        
    }

    if ( $ExitCode -eq $null -or $ExitCode -eq 0 ) {
        $ExitCode = -1
        Write-Output("ExitCode set to $ExitCode")        
    }
    Write-Output("Final ExitCode $ExitCode")
    cmd /c exit $ExitCode    #Set $LASTEXITCODE
    Write-Output("Final LASTEXITCODE $LASTEXITCODE")
    Write-Output("**************************")
    return    
} finally {
    Write-Output("$(Log-Date)")
}
Write-Output("Uninstallation succeeded")
cmd /c exit 0    #Set $LASTEXITCODE
Write-Output("LASTEXITCODE $LASTEXITCODE")
Write-Output("**************************")
