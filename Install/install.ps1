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

    Import-Module WebAdministration

    $MyInvocation.MyCommand.Path
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $GitRepoRoot = Split-Path -Parent $ScriptDir
    $WebSiteRootPath = Join-Path $GitRepoRoot 'web'

    Write-Output("$(Log-Date)")

    Write-Output ("WebSiteName: $WebSiteName")
    Write-Output ("WebSitePort: $WebSitePort")
    
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

    Write-Output ("Web Site Name = $WebSiteName")

    # Add the IIS feature ASP 4.x.
    $ASPNET45 = Get-WindowsOptionalFeature -Online | Where-Object {$_.state -eq "Enabled" -and $_.FeatureName -eq 'IIS-ASPNET45'}
    if ( $ASPNET45 -eq $null ) {
        Write-Output("Enabling ASP.NET 4.5")
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASPNET45
        Write-Output("Finished enabling ASP.NET 4.5")
    }

    # Create a new web site in c:\inetpub\wwwroot_git and set the port number to 8090.
    $HubSite = Get-ChildItem iis:\Sites | Where-Object{$_.Name -eq $WebSiteName}
    $HubSite
    if ( $HubSite -eq $null) {
        Write-Output( "Create web site")
        $HubSite = New-Item iis:\Sites\$WebSiteName -bindings @{protocol="http";bindingInformation="*:$($WebSitePort):"} -physicalPath $WebSiteRootPath -Force 
    }

    Write-Output( "Does AppPool $WebSiteName exist?")
    $AppPool = Get-ChildItem iis:\AppPools | Where-Object{$_.Name -eq $WebSiteName}
    if ( $AppPool -eq $null ) {
        Write-Output( "No, create an App Pool")
        $AppPool = new-item iis:\AppPools\$WebSiteName
    }

    # Set the App Pool user to LocalSystem. Advanced Settings\Identity:
    # So that Git Deploy Hub has permission to use the ssh file
    # And web site may be stopped.
    # And web processes may be stopped
    # etc
    $AppPool.processModel.identityType = "LocalSystem"
    $AppPool | set-Item

    # Associate website with App Pool
    Set-ItemProperty IIS:\Sites\$WebSiteName -name applicationPool -value $WebSiteName

    Write-Output("Application Pool...")
    $AppPool

    Write-Output ("Create a hub application in $WebSiteName web site, path $WebSiteRootPath, Pool $($AppPool.name)")
    New-WebApplication -Name "Hub" -Site $WebSiteName -PhysicalPath $WebSiteRootPath -ApplicationPool $AppPool.name -Force

    Write-Output("Web Application created")
    
    # Set the default git environment to be the currently logged on user so that the same SSH key is used for system processes.
    # Set the HOME environment SYSTEM variable to the current users home directory:
    if ( -not (test-path $ENV:HOMEDRIVE) -or (-not (test-path $ENV:HOMEPATH))) {
        Write-Output ("HOMEDRIVE $ENV:HOMEDRIVE or HOMEPATH $ENV:HOMEPATH does not exist. Use administrator instead")
        if ( -not (test-path 'c:\users\administrator')) {
            Write-Output ("No home directory can be derived")
            throw
        } else {
            $HOME2 = 'c:\users\administrator'
        }
                   
    } else {
        $HOME2 = Join-Path $ENV:HOMEDRIVE $ENV:HOMEPATH
    }
    Write-Output ("Home environment $HOME2")
    [Environment]::SetEnvironmentVariable('HOME', $HOME2 , 'Machine')

    # Start web site provided iis server is running
    $iis = get-wmiobject Win32_Service -Filter "name='w3svc'"
    if ( $iis -ne $null -and $iis.state -eq 'Running') {
        Start-Website -name $WebSiteName
    }
} catch {
    $e = $_.Exception
    $e|format-list -force
    
    Write-Output("Installation failed")
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
Write-Output("Installation succeeded")
cmd /c exit 0    #Set $LASTEXITCODE
Write-Output("LASTEXITCODE $LASTEXITCODE")
Write-Output("**************************")