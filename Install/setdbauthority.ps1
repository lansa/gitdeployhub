<#
.SYNOPSIS

Make LocalSystem owner of the database so that tables may be created when deploying a target system.
Also make LocalSystem able to create logins which is part of creating a table - the schema is a login

This script is running as Administrator

This script is expected to be run as provided in the example below. An alternative is to run
this command first before the script may be executed
    powershell Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine

.EXAMPLE
powershell.exe -ExecutionPolicy Bypass .\Set-DbAuthority.ps1 'MyServer' 'MyDbName'

#>

param (
    [Parameter(Mandatory=$true)]
        [string]
        $DbServerName,

    [Parameter(Mandatory=$true)]
        [string]
        $DbName,

    [Parameter(Mandatory=$false)]
        [string]
        $AdminUser = "Admin",

    [Parameter(Mandatory=$false)]
        [string]
        $AdminPassword = "Pcxuser122"
        
)

function Log-Date 
{
    ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ssZ")
}

$MyInvocation.MyCommand.Path

cmd /c exit 0   #Set $LASTEXITCODE

# Put try/catch/finally in its own block in order to have multiple successful exit points from try i.e. return
. {
    try {
        #Requires -RunAsAdministrator

        $LoginName = 'NT AUTHORITY\SYSTEM'
        $rolename = 'db_owner'
        $svrolename = 'securityadmin'
        
        [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
        [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Management.Common')
 
        $assemblylist =   
"Microsoft.SqlServer.Management.Common",  
"Microsoft.SqlServer.Smo",  
"Microsoft.SqlServer.Dmf ",  
"Microsoft.SqlServer.Instapi ",  
"Microsoft.SqlServer.SqlWmiManagement ",  
"Microsoft.SqlServer.ConnectionInfo ",  
"Microsoft.SqlServer.SmoExtended ",  
"Microsoft.SqlServer.SqlTDiagM ",  
"Microsoft.SqlServer.SString ",  
"Microsoft.SqlServer.Management.RegisteredServers ",  
"Microsoft.SqlServer.Management.Sdk.Sfc ",  
"Microsoft.SqlServer.SqlEnum ",  
"Microsoft.SqlServer.RegSvrEnum ",  
"Microsoft.SqlServer.WmiEnum ",  
"Microsoft.SqlServer.ServiceBrokerEnum ",  
"Microsoft.SqlServer.ConnectionInfoExtended ",  
"Microsoft.SqlServer.Management.Collector ",  
"Microsoft.SqlServer.Management.CollectorEnum",  
"Microsoft.SqlServer.Management.Dac",  
"Microsoft.SqlServer.Management.DacEnum",  
"Microsoft.SqlServer.Management.Utility"  

foreach ($asm in $assemblylist)  
{  
    $asm = [Reflection.Assembly]::LoadWithPartialName($asm)  
} 
        if ( $AdminUser.Length -gt 0 -and $AdminPassword.Length -gt 0) {
            $conn = new-object Microsoft.SqlServer.Management.Common.ServerConnection($DbServerName, $AdminUser, $AdminPassword)
        
            if ( $conn -eq $null) {
                Write-Error("$(Log-Date) Failed to create connection object")
                throw
            }        
        } else {
            $conn = new-object Microsoft.SqlServer.Management.Common.ServerConnection($DbServerName)
            if ( $conn -eq $null) {
                Write-Error("$(Log-Date) Failed to create connection object")
                throw
            }        
        }

        $srv = New-Object Microsoft.SqlServer.Management.Smo.Server( $Conn)
        if ( $srv -eq $null) {
            Write-Error("$(Log-Date) Server $DbServerName not available")
            throw
        }
        Write-Output( "$(Log-Date) Server object created successfully. Login errors occur with next request." )

        $svrole = $srv.Roles | where {$_.Name -eq $svrolename}
        $svrole = $srv.Roles[ $svrolename ]
        if ( $svrole -eq $null) {
            Write-Error("$(Log-Date) Server Role $svrolename not in database server $DbServerName")
            throw
        }
        $svrole.AddMember( $LoginName )

        $db = $srv.Databases | where { $_.Name -eq $dbname }
        if ( $db -eq $null) {
            Write-Error("$(Log-Date) Database $dbname not in database server $DbServerName")
            throw
        }

        $login = $Srv.Logins[ $LoginName ]
        if ( $login -eq $null) {
            Write-Error("$(Log-Date) Login $LoginName not in database $dbname")
            throw
        }

        # Check to see if the login is a user in this database
        $usr = $db.Users[$LoginName]
        if ($usr -eq $null) {
            # Check if login is mapped to another user in this database
            $mappedUsr = $db.users | where {$_.Login -eq $LoginName}
            if ($mappedUsr -ne $null) { 
                Write-Output("$(Log-Date) login is mapped to user $($mappedUsr.Name) in the db")
            } else {
                Write-Output("$(Log-Date) User does not exist in database so add it")
                $usr = New-Object ('Microsoft.SqlServer.Management.Smo.User') ($db, $LoginName)
                $usr.Login = $LoginName
                $usr.Create()
            }
        } else {
            Write-Output("$(Log-Date) User $LoginName already exists in database $dbname")
        }

        # Once we have a valid user in the database, check to see if the user is already a member of the role.  
        if ($usr -ne $null -and $usr.IsMember($rolename) -eq $True) {
            Write-Output("$(Log-Date) User already has role $rolename in database $dbname")
            return
        }

        # Get the role object if it exists
        $Role = $DB.Roles[$RoleName]
        if ($Role -eq $null) #Check to see if the role already exists in the database
        {
            Write-Error("$(Log-Date) Role $rolename not in database $dbname")
            throw
        }      
        $Role.AddMember( $LoginName )
    } catch {
        $e = $_.Exception
        $e|format-list -force
        
        Write-Output("$(Log-Date) Database Configuration failed")
        Write-Output("$(Log-Date) Raw LASTEXITCODE $LASTEXITCODE")  
        if ( (-not [string]::IsNullOrWhiteSpace($LASTEXITCODE)) -and ($LASTEXITCODE -ne 0)) {
            $ExitCode = $LASTEXITCODE
            Write-Output("$(Log-Date) ExitCode set to LASTEXITCODE $ExitCode")        
        } else {
            $ExitCode =  $e.HResult
            Write-Output("$(Log-Date) ExitCode set to HResult $ExitCode")        
        }

        if ( $ExitCode -eq $null -or $ExitCode -eq 0 ) {
            $ExitCode = -1
            Write-Output("$(Log-Date) ExitCode set to $ExitCode")        
        }
        Write-Output("$(Log-Date) Final ExitCode $ExitCode")
        cmd /c exit $ExitCode    #Set $LASTEXITCODE
    } finally {
        Write-Output("$(Log-Date)")
    }
}
if ( $LASTEXITCODE -eq 0) {
    Write-Output("$(Log-Date) Database Configuration succeeded")
}
Write-Output("$(Log-Date) LASTEXITCODE $LASTEXITCODE")
Write-Output("$(Log-Date) **************************")