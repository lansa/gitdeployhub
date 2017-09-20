<#
.SYNOPSIS

Configure GitDeployHub for a single target LANSA environment

.EXAMPLE

#>

#Requires -RunAsAdministrator

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

