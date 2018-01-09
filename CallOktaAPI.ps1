#Requires -Module OktaAPI
Import-Module OktaAPI

# Call this before calling Okta API functions. Replace YOUR_API_TOKEN and YOUR_ORG with your values.
# Connect-Okta "YOUR_API_TOKEN" "https://YOUR_ORG.oktapreview.com"
# Or place the Connect-Okta call in OktaAPISettings.ps1
.\OktaAPISettings.ps1

# This file contains functions with sample code. To use one, call it.

function Get-Logs() {
    $filePath = "Log.json"
    $fromTime = Get-Date -Format s
    $fromTime = $fromTime.Substring(0,10) + "T00%3A00%3A00Z"
    $toTime = Get-Date -Format s
    $toTime = $fromTime.Substring(0,10) + "T23%3A59%3A59Z"

    $flush = 50 # Flush memory every N pages
    $minRemaining = 10

    $allLogs = @()
    $pages = 0

    $params = @{since = $fromTime; until = $toTime; sortOrder = "DESCENDING"}
    "[" | Out-File $filePath
    do {
        $page = Get-OktaLogs @params
        $allLogs += $page.objects # these are converted from JSON, but then we convert back to JSON. TODO: optimize.
        $pages++
        if ($pages -eq $flush) {
            Flush-File $allLogs
            "," | Out-File $filePath -Append
            $allLogs = @()
            $pages = 0
        }
        if ($page.limitRemaining -lt $minRemaining) {
            do {
                Start-Sleep 1
                $now = [DateTimeOffset]::Now.ToUnixTimeSeconds()
            } until ($now -gt $page.limitReset)
        }
        $params = @{url = $page.nextUrl}
    } while ($page.nextUrl)

    Flush-File $allLogs

    "]" | Out-File $filePath -Append
}

function Flush-File($allLogs) {
    $s = $allLogs | ConvertTo-Json -Compress
    $s = $s.substring(1, $s.length - 2) # remove first "[" and last "]"
    $s | Out-File $filePath -Append
}

function Get-DeprovisionedUsers {
    $totalUsers = 0
    $params = @{limit = 25; filter = 'status eq "DEPROVISIONED"'} # default is 200, test with a smaller page.
    do {
        $page = Get-OktaUsers @params
        $users = $page.objects
        foreach ($user in $users) {
            Write-Host $user.profile.login $user.credentials.provider.type
            Remove-OktaUser $user.id
        }
        $totalUsers += $users.count
        $params = @{url = $page.nextUrl}
    } while ($page.nextUrl)
    "$totalUsers users found."
}

function Export-Groups {
    $totalGroups = 0
    $exportedgroups = @()
    $params = @{filter = 'type eq "OKTA_GROUP"'; paged = $true}
    do {
        $page = Get-OktaGroups @params
        $groups = $page.objects
        foreach ($group in $groups) {
            $exportedgroups += [PSCustomObject]@{id =$group.id; name = $group.profile.name}
        }
        $totalGroups += $groups.count
        $params = @{url = $page.nextUrl; paged = $true}
    } while ($page.nextUrl)
    $exportedgroups | Export-Csv exportedgroups.csv -notype
    "$($groups.count) groups exported." 
}

function Export-Users {
    $totalUsers = 0
    $exportedusers = @()
# for more filters, see http://developer.okta.com/docs/api/resources/users.html#list-users-with-a-filter
    $params = @{filter = 'status eq "ACTIVE"'}
    do {
        $page = Get-OktaUsers @params
        $users = $page.objects
        foreach ($user in $users) {
            $exportedusers += [PSCustomObject]@{id = $user.id; name = $user.profile.login}
        }
        $totalUsers += $users.count
        $params = @{url = $page.nextUrl}
    } while ($page.nextUrl)
    $exportedusers | Export-Csv exportedusers.csv -notype
    "$totalUsers users found."
}

function Export-UsersAndGroups {
    $totalUsers = 0
    $exportedusers = @()
# for more filters, see http://developer.okta.com/docs/api/resources/users.html#list-users-with-a-filter
    $params = @{filter = 'status eq "ACTIVE"'}
    do {
        $page = Get-OktaUsers @params
        $users = $page.objects
        foreach ($user in $users) {
            $userGroups = Get-OktaUserGroups $user.id
            $groups = @()
            foreach ($userGroup in $userGroups) {
                if ($userGroup.type -eq "OKTA_GROUP") {
                    $groups += $userGroup.profile.name
                }
            }
            $exportedusers += [PSCustomObject]@{id = $user.id; name = $user.profile.login; groups = $groups -join ";"}
        }
        $totalUsers += $users.count
        $params = @{url = $page.nextUrl}
    } while ($page.nextUrl)
    $exportedusers | Export-Csv exportedusersgroups.csv -notype
    "$totalUsers users exported."
}

function Get-PagedAppUsers {
    $totalAppUsers = 0
    $params = @{appid = "0oa6k5e19jwu8aEAS0h7"; limit = 2}
    do {
        $page = Get-OktaAppUsers @params
        $appusers = $page.objects
        foreach ($appuser in $appusers) {
            Write-Host $appuser.credentials.userName
        }
        $totalAppUsers += $appusers.count
        $params = @{url = $page.nextUrl}
    } while ($page.nextUrl)
    "$totalAppUsers app users found."
}

function Enroll-Factor {
    $userid = ""
    $factor = @{factorType = "token"; provider = "RSA"; profile = @{credentialId = ""}; verify = @{passCode = ""}}
    Set-OktaFactor $userid $factor
}

# Read groups from CSV and create them in Okta.
function Create-Groups {
    $groups = Import-Csv groups.csv
    $importedgroups = @()
    foreach ($group in $groups) {
        $profile = @{name = $group.name; description = $group.description}
        try {
            $oktagroup = New-OktaGroup @{profile = $profile}
            $message = "New group"
        } catch {
            Get-Error $_
            try {
                $oktagroup = Get-OktaGroups $group.name 'type eq "OKTA_GROUP"'
                $message = "Found group"
            } catch {
                Get-Error $_
                $oktagroup = $null
                $message = "Invalid group"
            }
        }
        $importedgroups += [PSCustomObject]@{id = $oktagroup.id; name = $group.name; message = $message}
    }
    $importedgroups | Export-Csv importedgroups.csv -notype
    "$($groups.count) groups read." 
}

# Read users from CSV, create them in Okta, and add to a group.
function Import-Users {
<# Sample users.csv file with 5 fields. Make sure you include the header line as the first record.
login,email,firstName,lastName,groupid
testa1@okta.com,testa1@okta.com,Test,A1,00g5gtwaaeOe7smEF0h7
testa2@okta.com,testa2@okta.com,Test,A2,00g5gtwaaeOe7smEF0h7
#>
    $users = Import-Csv users.csv
    $importedUsers = @()
    foreach ($user in $users) {
        $profile = @{login = $user.login; email = $user.email; firstName = $user.firstName; lastName = $user.lastName}
        $message = ""
        try {
            $oktaUser = New-OktaUser @{profile = $profile} $false
        } catch {
            try {
                $oktaUser = Get-OktaUser $user.login
            } catch {
                $oktaUser = $null
                $message = "Invalid user."
            }
        }
        if ($oktaUser) {
            try {
                Add-OktaGroupMember $user.groupid $oktaUser.id
            } catch {
                $message = "Invalid group."
            }
        }
        $importedUsers += [PSCustomObject]@{id = $oktaUser.id; login = $user.login; message = $message}
    }
    $importedUsers | Export-Csv importedUsers.csv -NoTypeInformation
    "$($users.count) users read."
}

function New-Users {
    for ($i = 1; $i -le 3; $i++) {
        $now = Get-Date -Format "yyyyMMddHHmmss"
        $profile = @{login="a$now$i@okta.com"; email="testuser$i@okta.com"; firstName="test"; lastName="a$i"}
        try {
            New-OktaUser @{profile = $profile} $false
        } catch {
            Get-Error $_
        }
    }
}

function Add-GroupMember {
    $me = Get-OktaUser "me"
    $group = Get-OktaGroups "PowerShell" 'type eq "OKTA_GROUP"'
    Add-OktaGroupMember $group.id $me.id
}

function Rename-Users {
    $page = Get-OktaUsers -filter 'status eq "DEPROVISIONED"'
    $users = $page.objects
    # $oktaCredUsers = $users | where {$_.credentials.provider.type -eq "OKTA"}
    foreach ($user in $users) {
        if ($user.credentials.provider.type -eq "OKTA") {
            $url = Enable-OktaUser $user.id $false
            $updatedUser = Set-OktaUser $user.id @{profile = @{email = "test@gsroka.local"}}
            Disable-OktaUser $user.id
        }
    }
    "$($users.count) users found."
}

function Get-PagedUsers {
    $totalUsers = 0
    $params = @{limit = 25}
    do {
        $page = Get-OktaUsers @params
        $users = $page.objects
        foreach ($user in $users) {
            Write-Host $user.profile.login $user.credentials.provider.type
        }
        $totalUsers += $users.count
        $params = @{url = $page.nextUrl}
    } while ($page.nextUrl)
    "$totalUsers users found."
}

function Get-PagedMembers {
    $totalUsers = 0
    $params = @{id = "00g6fnikz1KOvNPK70h7"; limit = 1; paged = $true}
    do {
        $page = Get-OktaGroupMember @params
        $users = $page.objects
        foreach ($user in $users) {
            Write-Host $user.profile.login
        }
        $totalUsers += $users.count
        $params = @{url = $page.nextUrl; paged = $true}
    } while ($page.nextUrl)
    "$totalUsers users found."
}

function Get-Events {
    $today = Get-Date -Format "yyyy-MM-dd"
    Get-OktaEvents "$($today)T00:00:00.0-08:00"
    # Get-OktaEvents -filter 'published gt "2015-12-21T16:00:00.0-08:00"'
}

function Get-Headers {
    $urlLimit = 1200 # this varies by URL
    $remaining = $urlLimit
    for ($i = 1; $i -le 5000; $i++) {
        $now = [DateTimeOffset]::Now.ToUnixTimeSeconds()
        if ($remaining -gt 20) {
            try {
                $page = Get-OktaUsers -filter 'profile.login eq "gabriel.sroka@lokta.com"'
                $limit = [int64]$page.response.Headers.'X-Rate-Limit-Limit'
                $remaining = [int64]$page.response.Headers.'X-Rate-Limit-Remaining'
                $reset = [int64]$page.response.Headers.'X-Rate-Limit-Reset'
                Write-Host "now: " + $now + " remaining: " + $remaining + " reset: " + $reset
            } catch {
                Write-Host "Error ! (need to redo last call)."
                $remaining = 0
            }
        } else {
            Write-Host "waiting, now: " + $now + " reset: " + $reset
            if ($now -gt $reset) {
                Write-Host "reset"
                $remaining = $urlLimit
            }
            Start-Sleep -second 1
        }
    }
}

<#
$ids = "me#jane.doe".split("#")
foreach ($id in $ids) {
    $user = Get-OktaUser $id
}
#>



<#PSScriptInfo
.VERSION 1.1.3
.GUID 33ca8742-b9bf-4824-9d86-605a8d627cb4
.AUTHOR Gabriel Sroka
.PROJECTURI https://github.com/gabrielsroka/OktaAPI.psm1
.DESCRIPTION Call Okta API.
#> 
