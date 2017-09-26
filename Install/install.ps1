<#
.SYNOPSIS

Install GitDeployHub

This script presumes that the GitDeployHub git repo has been cloned into a directory of this form:
c:\inetpub\wwwroot_git\GitDeployHub. Though it should not make any difference

IIS is already enabled

This script is running as Administrator

This command must be run external to this script before this script and other scripts executed by GitDeplyHub may be executed
    powershell Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine


.EXAMPLE

#>

#Requires -RunAsAdministrator

Import-Module WebAdministration

# Check the execution policy allows LocalSystem user to execute scripts
Get-ExecutionPolicy -List
$ExecutionPolicy = Get-ExecutionPolicy -Scope MachinePolicy
if ( -not ($ExecutionPolicy -eq 'Unrestricted' -or $ExecutionPolicy -eq 'Bypass')) {
    $ExecutionPolicy = Get-ExecutionPolicy -Scope LocalMachine
    if ( -not ($ExecutionPolicy -eq 'Unrestricted' -or $ExecutionPolicy -eq 'Bypass')) {
        Write-Error ("ExecutionPolicy for MachinePolicy scope or LocalMachine scope need to be Unrestricted or Bypass in order for GitDeployHub scripts to be able to execute. Execute this on the command line  powershell Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine")
        throw
    }        
}

$logfile = "$ENV:TEMP\GitDeployHubInstall.log"
$MyInvocation.MyCommand.Path
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$GitRepoRoot = Split-Path -Parent $ScriptDir
$WebSiteRootPath = Join-Path $GitRepoRoot 'web'

# Add the IIS feature ASP 4.x.
$ASPNET45 = Get-WindowsOptionalFeature -Online | Where-Object {$_.state -eq "Enabled" -and $_.FeatureName -eq 'IIS-ASPNET45'}
if ( $ASPNET45 -eq $null ) {
    Write-Output("Enabling ASP.NET 4.5")
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASPNET45
    Write-Output("Finished enabling ASP.NET 4.5")
}

# Create a new web site in c:\inetpub\wwwroot_git and set the port number to 8090.
$WebSiteName = 'TestSite'
Get-ChildItem iis:\Sites | Where-Object{$_.Name -eq $WebSiteName}
New-Item iis:\Sites\$WebSiteName -bindings @{protocol="http";bindingInformation="*:8090:"} -physicalPath $WebSiteRootPath -Force 

# Create an App Pool

$AppPool = Get-ChildItem iis:\AppPools | Where-Object{$_.Name -eq $WebSiteName}
if ( $AppPool -eq $null ) {
    new-item iis:\AppPools\$WebSiteName
}

# Set the App Pool user to LocalSystem. Advanced Settings\Identity:
# So that Git Deploy Hub has permission to use the ssh file
$AppPool.processModel.identityType = "LocalSystem"
$AppPool | set-Item

# Associate website with App Pool
Set-ItemProperty IIS:\Sites\$WebSiteName -name applicationPool -value $WebSiteName

# Set the default git environment to be the currently logged on user so that the same SSH key is used for system processes.
# Set the HOME environment SYSTEM variable to the current users home directory:

$HOME2 = Join-Path $ENV:HOMEDRIVE $ENV:HOMEPATH
Write-Output ("Home environment $HOME2")
[Environment]::SetEnvironmentVariable('HOME', $HOME2 , 'Machine')

Start-Website -name $WebSiteName
