<#
.SYNOPSIS

Configure GitDeployHub for a single target LANSA environment

Presumed to be running from within the website that is being configured

.EXAMPLE

.\Install\Config.ps1 MyTargetSystemName 'C:\Program Files (x86)\LANSA' DEMO $true

#>

param (
    [Parameter(Mandatory=$true)]
        [string]
        $TargetSystem,

    [Parameter(Mandatory=$true)]
        [String] 
        $folder,
        
    [Parameter(Mandatory=$true)]
        [String] 
        $APPL,
        
    [Parameter(Mandatory=$false)]
        [Boolean] 
        $AddConfig = $true
)

#Requires -RunAsAdministrator

$TargetSystem
$folder
$APPL
$AddConfig

$MyInvocation.MyCommand.Path
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$GitRepoRoot = Split-Path -Parent $ScriptDir
$WebSiteRootPath = Join-Path $GitRepoRoot 'web'
$Config = Join-Path $WebSiteRootPath 'web.config'

$doc = New-Object System.Xml.XmlDocument
$doc.Load($Config)

$Instance = $doc.SelectSingleNode('configuration/gitDeployHub/instances/instance[@name="' + $TargetSystem + '"]')
$Instances = $doc.SelectSingleNode('configuration/gitDeployHub/instances')

if ( $AddConfig) {
    if ( $Instance -eq $null ) {
        $Instance = $Instances.AppendChild($doc.CreateElement("instance"));
        $Instance.SetAttribute("name",$TargetSystem);
    }
    $Instance.SetAttribute("folder",$folder);
    $Instance.SetAttribute("projectFolder", "X_Win95\X_Lansa\X_Apps\$APPL");
    $Instance
} else {
    if ( $Instance -eq $null ) {
        Write-Error ("Instance $TargetSystem does not exist")
    } else {
        $Instance.ParentNode.RemoveChild($Instance)
    }
}
$doc.Save($Config)