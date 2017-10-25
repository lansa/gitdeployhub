<#
.SYNOPSIS

Make LocalSystem owner of the database so that tables may be created when deploying a target system

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
        $DbName
)

function Log-Date 
{
    ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ssZ")
}

$MyInvocation.MyCommand.Path

cmd /c exit 0   #Set $LASTEXITCODE

# Put try/catch/finally in its own block in order to have multiple successful exit points from try
. {
    try {
        #Requires -RunAsAdministrator

        $LoginName = 'NT AUTHORITY\SYSTEM'
        $rolename = 'db_owner'

        [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
        $srv = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $DbServerName
        if ( $srv -eq $null) {
            Write-Error("Server $DbServerName not available or not using trusted connection")
            throw
        }

        $db = $srv.Databases | where { $_.Name -eq $dbname }
        if ( $db -eq $null) {
            Write-Error("Database $dbname not in database server")
            throw
        }

        $login = $Srv.Logins[ $LoginName ]
        if ( $login -eq $null) {
            Write-Error("Login $LoginName not in database")
            throw
        }

        # Check to see if the login is a user in this database
        $usr = $db.Users[$LoginName]
        if ($usr -eq $null) {
            # Check if login is mapped to another user in this database
            $mappedUsr = $db.users | where {$_.Login -eq $LoginName}
            if ($mappedUsr -ne $null) { 
                Write-Output("login is mapped to user $($mappedUsr.Name) in the db")
            } else {
                Write-Output("User does not exist in database so add it")
                $usr = New-Object ('Microsoft.SqlServer.Management.Smo.User') ($db, $LoginName)
                $usr.Login = $LoginName
                $usr.Create()
            }
        } else {
            Write-Output("User already exists in database")
        }

        # Once we have a valid user in the database, check to see if the user is already a member of the role.  
        if ($usr -ne $null -and $usr.IsMember($rolename) -eq $True) {
            Write-Output("User already has role $rolename in database")
            return
        }

        # Get the role object if it exists
        $Role = $DB.Roles[$RoleName]
        if ($Role -eq $null) #Check to see if the role already exists in the database
        {
            Write-Error("Role $rolename not in database")
            throw
        }      
        $Role.AddMember( $LoginName )
    } catch {
        $e = $_.Exception
        $e|format-list -force
        
        Write-Output("Database Configuration failed")
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
    } finally {
        Write-Output("$(Log-Date)")
    }
}
if ( $LASTEXITCODE -eq 0) {
    Write-Output("Database Configuration succeeded")
}
Write-Output("LASTEXITCODE $LASTEXITCODE")
Write-Output("**************************")