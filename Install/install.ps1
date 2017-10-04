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
    [Parameter(Mandatory=$false)]
        [string]
        $WebSiteName,

    [Parameter(Mandatory=$false)]
        [string]
        $WebSitePort = 8090 
)

#Requires -RunAsAdministrator

Import-Module WebAdministration

$MyInvocation.MyCommand.Path
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$GitRepoRoot = Split-Path -Parent $ScriptDir
$WebSiteRootPath = Join-Path $GitRepoRoot 'web'

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
    New-Item iis:\Sites\$WebSiteName -bindings @{protocol="http";bindingInformation="*:$($WebSitePort):"} -physicalPath $WebSiteRootPath -Force 

    # Create an App Pool

    $AppPool = Get-ChildItem iis:\AppPools | Where-Object{$_.Name -eq $WebSiteName}
    if ( $AppPool -eq $null ) {
        new-item iis:\AppPools\$WebSiteName
    }

    # Set the App Pool user to LocalSystem. Advanced Settings\Identity:
    # So that Git Deploy Hub has permission to use the ssh file
    #$AppPool.processModel.identityType = "LocalSystem"
    #$AppPool | set-Item

    # Associate website with App Pool
    Set-ItemProperty IIS:\Sites\$WebSiteName -name applicationPool -value $WebSiteName
} 

Write-Output ("Create a hub application in the existing site")
New-WebApplication -Name "Hub" -Site $WebSiteName -PhysicalPath $WebSiteRootPath -ApplicationPool $HubSite.applicationPool

# Set the default git environment to be the currently logged on user so that the same SSH key is used for system processes.
# Set the HOME environment SYSTEM variable to the current users home directory:

$HOME2 = Join-Path $ENV:HOMEDRIVE $ENV:HOMEPATH
Write-Output ("Home environment $HOME2")
[Environment]::SetEnvironmentVariable('HOME', $HOME2 , 'Machine')

Start-Website -name $WebSiteName
