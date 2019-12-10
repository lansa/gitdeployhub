<#
.SYNOPSIS

Install GitDeployHub

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
powershell.exe -ExecutionPolicy Bypass .\install.ps1 -WebSiteName 'testgit' -WebSitePort '8099'

#>

param (
    [Parameter(Mandatory=$true)]
        [string]
        $WebSiteName,

    [Parameter(Mandatory=$true)]
        [string]
        $WebSitePort
)

function Log-Date
{
    ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ssZ")
}

cmd /c exit 0    #Set $LASTEXITCODE

try {
    #Requires -RunAsAdministrator

    Import-Module WebAdministration | Out-Default | Write-Host

    $MyInvocation.MyCommand.Path | Out-Default | Write-Host
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $GitRepoRoot = Split-Path -Parent $ScriptDir
    $WebSiteRootPath = Join-Path $GitRepoRoot 'web'

    Write-Host("$(Log-Date)")

    Write-Host ("WebSiteName: $WebSiteName")
    Write-Host ("WebSitePort: $WebSitePort")

    # Default install location is c:\inetpub\wwwroot_git
    # LANSA Path is c:\program files(x86)\mycompany\myapp\tools
    # If its the default path, call the website 'git'
    # If its the LANSA path, use 'myapp'

    if ( [string]::IsNullOrWhiteSpace($WebSiteName) ) {
        $TempName = split-path -Parent $GitRepoRoot | split-path -Parent | split-path -Leaf
        if ( $TempName -eq 'inetpub') {
            $WebSiteName = 'git'
        } else {
            $WebSiteName = $TempName
        }
    }

    Write-Host ("Web Site Name = $WebSiteName")

    # Add the IIS feature ASP 4.x.
    $ASPNET45 = Get-WindowsOptionalFeature -Online | Where-Object {$_.state -eq "Enabled" -and $_.FeatureName -eq 'IIS-ASPNET45'}
    if ( $null -eq $ASPNET45 ) {
        Write-Host("Enabling ASP.NET 4.5")
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASPNET45 -All | Out-Default | Write-Host
        Write-Host("Finished enabling ASP.NET 4.5")
    }

    # Create a new web site in c:\inetpub\wwwroot_git and set the port number to 8090.
    $HubSite = Get-ChildItem iis:\Sites | Where-Object{$_.Name -eq $WebSiteName}
    $HubSite | Out-Default | Write-Host
    if ( $null -eq $HubSite ) {
        Write-Host( "Create web site")
        $HubSite = New-Item iis:\Sites\$WebSiteName -bindings @{protocol="http";bindingInformation="*:$($WebSitePort):"} -physicalPath $WebSiteRootPath -Force
    }

    Write-Host( "Does AppPool $WebSiteName exist?")
    $AppPool = Get-ChildItem iis:\AppPools | Where-Object{$_.Name -eq $WebSiteName}
    if ( $null -eq $AppPool ) {
        Write-Host( "No, create an App Pool")
        $AppPool = new-item iis:\AppPools\$WebSiteName
    }

    # Set the App Pool user to LocalSystem. Advanced Settings\Identity:
    # So that Git Deploy Hub has permission to use the ssh file
    # And web site may be stopped.
    # And web processes may be stopped
    # etc
    $AppPool.processModel.identityType = "LocalSystem"
    $AppPool | set-Item | Out-Default | Write-Host

    # Associate website with App Pool
    Set-ItemProperty IIS:\Sites\$WebSiteName -name applicationPool -value $WebSiteName

    Write-Host("Application Pool...")
    $AppPool | Out-Default | Write-Host

    Write-Host ("Create a hub application in $WebSiteName web site, path $WebSiteRootPath, Pool $($AppPool.name)")
    New-WebApplication -Name "Hub" -Site $WebSiteName -PhysicalPath $WebSiteRootPath -ApplicationPool $AppPool.name -Force | Out-Default | Write-Host

    Write-Host("Web Application created")

    # *************************************************************************
    Write-Host( "Setup git ssh key permissions")
    # Firstly ensure the systemprofile .ssh directory exists. It should already contain the ssh key.
    # If it doesn't then there will be an error anyway
    $SysHomeDir = 'C:\windows\System32\config\systemprofile\.ssh'
    if ( -not (Test-Path $SysHomeDir) ) {
        mkdir $SysHomeDir | Out-Default | Write-Host
    }
    dir $SysHomeDir\..

    # Full access to Everyone, especially for creating/updating known_hosts
    # cmd /C "icacls `"$SysHomeDir`" /grant:r Everyone:(CI)(OI)(F)  /inheritance:e"
    $Acl = Get-Acl $SysHomeDir
    $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $Acl.SetAccessRule($Ar) | Out-Default | Write-Host
    Set-Acl $SysHomeDir $Acl | Out-Default | Write-Host

    $RunKeyScanGit = $false
    $RunKeyScanInPath = $false
    if ( -not (Get-Command "ssh-keyscan.exe" -ErrorAction SilentlyContinue ) ) {
        $gitcmd = Get-Command git
        if ( $gitcmd ) {
            $gitpath = "$($gitcmd.Source)\..\.."
        } else {
            $gitpath = 'c:\program files\git'
            if ( -not (Test-Path $gitpath) ) {
                $gitpath = 'c:\program files (x86)\git'
                if ( -not (Test-Path $gitpath) ) {
                    $gitpath = 'c:\git'
                    if ( -not (Test-Path $gitpath) ) {
                        $gitpath = $null
                    }
                }
            }
        }

        if ($gitpath) {
            if ( Test-Path $Gitpath\usr\bin\ssh-keyscan.exe) {
                $RunKeyScanGit = $true
            } else {
                if ( -not ([string]::IsNullOrWhiteSpace($ENV:ChocolateyInstall) ) ) {
                    Write-Host("Re-install git to add back in ssh-keyscan.exe which was deleted from AWS Scalable image as it failed the AWS virus scan")
                    choco install git --force
                    if ( Test-Path "$Gitpath\usr\bin\ssh-keyscan.exe") {
                        $RunKeyScanGit = $true
                    }
                }
            }
        }
    } else {
        $RunKeyScanInPath = $true
    }

    if ( $RunKeyScanGit ) {
        # Quotes around the WHOLE cmd string so that the output is in ASCII not UTF-16
        cmd /C "`"$Gitpath\usr\bin\ssh-keyscan.exe`" github.com >> `"$SysHomeDir\known_hosts`""
        if ( $LASTEXITCODE -ne 0) {
            throw "Error creating $SysHomeDir\known_hosts"
        }
    }

    if ( $RunKeyScanInPath ) {
        # Quotes around the WHOLE cmd string so that the output is in ASCII not UTF-16
        cmd /C "ssh-keyscan.exe github.com >> `"$SysHomeDir\known_hosts`""
        if ( $LASTEXITCODE -ne 0) {
            throw "Error creating $SysHomeDir\known_hosts"
        }
    }

    if ( -not $RunKeyScanGit -and -not $RunKeyScanInPath ) {
        Write-Host("Warning: $SysHomeDir\known_hosts not setup as ssh-keyscan.exe is not available")
    }

    # *************************************************************************

    # Start web site provided iis server is running
    $iis = get-wmiobject Win32_Service -Filter "name='w3svc'"
    if ( $null -ne $iis -and $iis.state -eq 'Running') {
        Start-Website -name $WebSiteName | Out-Default | Write-Host
    }
} catch {
    $_ | Out-Default | Write-Host
    $e = $_.Exception
    $e|format-list -force | Out-Default | Write-Host

    Write-Host("Installation failed")

    Write-Host("Raw LASTEXITCODE $LASTEXITCODE")
    if ( (-not [string]::IsNullOrWhiteSpace($LASTEXITCODE)) -and ($LASTEXITCODE -ne 0)) {
        $ExitCode = $LASTEXITCODE
        Write-Host("ExitCode set to LASTEXITCODE $ExitCode")
    } else {
        $ExitCode =  $e.HResult
        Write-Host("ExitCode set to HResult $ExitCode")
    }

    if ( $null -eq $ExitCode -or $ExitCode -eq 0 ) {
        $ExitCode = -1
        Write-Host("ExitCode set to $ExitCode")
    }
    Write-Host("Final ExitCode $ExitCode")
    cmd /c exit $ExitCode    #Set $LASTEXITCODE
    Write-Host("Final LASTEXITCODE $LASTEXITCODE")
    Write-Host("**************************")
    return
} finally {
    Write-Host("$(Log-Date)")
}
Write-Host("Installation succeeded")
cmd /c exit 0    #Set $LASTEXITCODE
Write-Host("LASTEXITCODE $LASTEXITCODE")
Write-Host("**************************")