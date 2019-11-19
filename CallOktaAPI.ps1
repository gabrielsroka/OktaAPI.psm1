#Requires -Module OktaAPI
Import-Module OktaAPI

# API token comes from Okta Admin > Security > API > Tokens > Create Token
# see https://developer.okta.com/docs/guides/create-an-api-token

# Call Connect-Okta before calling Okta API functions. Replace YOUR_API_TOKEN and YOUR_ORG with your values.
# Connect-Okta "YOUR_API_TOKEN" "https://YOUR_ORG.oktapreview.com"
# Or place the Connect-Okta call in OktaAPISettings.ps1
.\OktaAPISettings.ps1

# This file contains functions with sample code. To use one, call it.

# Apps

function Add-SwaApp() {
    $user = Get-OktaUser "me"
    
    # see https://developer.okta.com/docs/api/resources/apps#add-custom-swa-application
    $app = @{
        label = "AAA Test App"
        settings = @{
            signOn = @{loginUrl = "https://aaatest.oktapreview.com"}
        }
        signOnMode = "AUTO_LOGIN"
        visibility = @{autoSubmitToolbar = $false}
    }
    $app = New-OktaApp $app

    # see https://developer.okta.com/docs/api/resources/apps#assign-user-to-application-for-sso
    $appuser = @{id = $user.id; scope = "USER"}
    Add-OktaAppUser $app.id $appuser
}

function Add-AppUser() {
    $app = Get-OktaApp "?q=A bookmark app"
    $user = Get-OktaUser "me"
    $appuser = @{id = $user.id; scope = "USER"}
    $appuser = Add-OktaAppUser $app.id $appuser
}

function Get-AllMyApps() {
    $user = Get-OktaUser "me"

    $totalApps = 0
    $params = @{filter = "user.id eq `"$($user.id)`""}
    do {
        $page = Get-OktaApps @params
        $apps = $page.objects
        foreach ($app in $apps) {
            Write-Host $app.id $app.label
        }
        $totalApps += $apps.count
        $params = @{url = $page.nextUrl}
    } while ($page.nextUrl)
    "$totalApps apps found."
}

function Get-PagedAppUsers($appid) {
    $totalAppUsers = 0
    $params = @{appid = $appid}
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

function Get-AppGroups($appid) {
    $total = 0
    $params = @{appid = $appid}
    do {
        $page = Get-OktaAppGroups @params
        $appgroups = $page.objects
        foreach ($appgroup in $appgroups) {
            $group = Get-OktaGroup $appgroup.id
            $licenses = $appgroup.profile.licenses -join ";"
            Write-Host $appgroup.id "," $group.profile.name "," $licenses
        }
        $total += $appgroups.count
        $params = @{url = $page.nextUrl}
    } while ($page.nextUrl)
    "$total app groups found."
}

function Set-AppUsers($appid) {
    $users = Import-Csv appusers.csv
    foreach ($user in $users) {
        $appUser = @{
            credentials = @{userName = $user.userName}
            scope = "USER"
        }
        $updAppUser = Set-OktaAppUser $appid $user.id $appUser
    }
}

function Remove-AppUser($appid, $login) {
    $user = Get-OktaUser $login
    $appUser = Set-OktaAppUser $appid $user.id @{scope = "USER"}
    Remove-OktaAppUser $appid $user.id
}

# Events

function Get-Events() {
    $today = Get-Date -Format "yyyy-MM-dd"
    Get-OktaEvents "$($today)T00:00:00.0-08:00"
    # Get-OktaEvents -filter 'published gt "2015-12-21T16:00:00.0-08:00"'
}

# Factors

function Get-MfaUsers() {
    $totalUsers = 0
    $mfaUsers = @()
    # for more filters, see https://developer.okta.com/docs/api/resources/users#list-users-with-a-filter
    $params = @{filter = 'status eq "ACTIVE"'}
    do {
        $page = Get-OktaUsers @params
        $users = $page.objects
        foreach ($user in $users) {
            $factors = Get-OktaFactors $user.id

            $sms = $factors.where({$_.factorType -eq "sms"})
            $call = $factors.where({$_.factorType -eq "call"})

            $mfaUsers += [PSCustomObject]@{
                id = $user.id
                name = $user.profile.login
                sms = $sms.factorType
                sms_enrolled = $sms.created
                sms_status = $sms.status
                call = $call.factorType
                call_enrolled = $call.created
                call_status = $call.status
            }
        }
        $totalUsers += $users.count
        $params = @{url = $page.nextUrl}
    } while ($page.nextUrl)
    $mfaUsers | Export-Csv mfaUsers.csv -notype
    "$totalUsers users found."
}

function Set-SMSFactor($userid) {
    $factor = @{factorType = "sms"; provider = "OKTA"; profile = @{phoneNumber = "+1-562-555-1212"}}
    $activate = $true # Activate SMS without sending one to the user.
    Set-OktaFactor $userid $factor $activate
}

function Enable-SMSFactor($userid, $factorid, $passCode) {
    # Wait for the user to get an SMS with a passCode, then enable the factor:
    Enable-OktaFactor $userid $factorid @{passCode = $passCode}
}

function Set-RSAFactor($userid) {
    $factor = @{factorType = "token"; provider = "RSA"; profile = @{credentialId = ""}; verify = @{passCode = ""}}
    Set-OktaFactor $userid $factor
}

# Groups

# Read groups from CSV and create them in Okta.
function New-Groups() {
<# Sample groups.csv file with 2 fields. Make sure you include the header line as the first record.
name,description
PowerShell Group,Members of this group are awesome.
#>
    $groups = Import-Csv groups.csv
    $importedGroups = @()
    foreach ($group in $groups) {
        $profile = @{name = $group.name; description = $group.description}
        try {
            $oktaGroup = New-OktaGroup @{profile = $profile}
            $message = "New group"
        } catch {
            Get-Error $_
            try {
                $oktaGroup = Get-OktaGroups $group.name 'type eq "OKTA_GROUP"'
                $message = "Found group"
            } catch {
                Get-Error $_
                $oktaGroup = $null
                $message = "Invalid group"
            }
        }
        $importedGroups += [PSCustomObject]@{id = $oktaGroup.id; name = $group.name; message = $message}
    }
    $importedGroups | Export-Csv importedGroups.csv -notype
    "$($groups.count) groups read." 
}

function Get-PagedGroupMembers($groupId) {
    $totalUsers = 0
    $params = @{id = $groupId; paged = $true}
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

function Add-GroupMember() {
    $user = Get-OktaUser "me"
    $group = Get-OktaGroups "PowerShell" 'type eq "OKTA_GROUP"'
    Add-OktaGroupMember $group.id $user.id
}

function Export-Groups() {
    $totalGroups = 0
    $exportedGroups = @()
    # type eq "OKTA_GROUP", "APP_GROUP" (including AD/LDAP), or "BUILT_IN" 
    # see https://developer.okta.com/docs/api/resources/groups#group-type
    $filter = 'type eq "APP_GROUP"' 
    $params = @{filter = $filter; paged = $true}
    do {
        $page = Get-OktaGroups @params
        $groups = $page.objects
        foreach ($group in $groups) {
            $exportedGroups += [PSCustomObject]@{id = $group.id; description = $group.profile.description; name = $group.profile.name}
        }
        $totalGroups += $groups.count
        $params = @{url = $page.nextUrl; paged = $true}
    } while ($page.nextUrl)
    $exportedGroups | Export-Csv exportedGroups.csv -notype
    "$($groups.count) groups exported." 
}

# Logs

function Get-Logs() {
    $filePath = "Log.json"
    $flush = 50 # Flush memory every N pages
    $limitRemaining = 10

    $fromTime = Get-Date -Format s
    $fromTime = $fromTime.Substring(0,10) + "T00%3A00%3A00Z"
    $toTime = Get-Date -Format s
    $toTime = $fromTime.Substring(0,10) + "T23%3A59%3A59Z"

    $allLogs = @()
    $pages = 0

    $params = @{since = $fromTime; until = $toTime; sortOrder = "DESCENDING"}
    "[" | Out-File $filePath
    do {
        $page = Get-OktaLogs @params
        $allLogs += $page.objects # these are converted from JSON, but then we convert back to JSON. TODO: optimize.
        $pages++
        if ($pages -eq $flush) {
            Flush-File $allLogs $filePath
            "," | Out-File $filePath -Append
            $allLogs = @()
            $pages = 0
        }
        if ($page.limitRemaining -lt $limitRemaining) {
            do {
                Start-Sleep 1
                $now = [DateTimeOffset]::Now.ToUnixTimeSeconds()
            } until ($now -gt $page.limitReset)
        }
        $params = @{url = $page.nextUrl}
    } while ($page.nextUrl)

    Flush-File $allLogs $filePath

    "]" | Out-File $filePath -Append
}

function Flush-File($allLogs, $filePath) {
    $s = $allLogs | ConvertTo-Json -Compress -Depth 100 # max depth is 100
    $s = $s.substring(1, $s.length - 2) # remove first "[" and last "]"
    $s | Out-File $filePath -Append
}

# Users

# Read users from CSV, create them in Okta, and add to a group. See also next function.
function Import-Users() {
<# Sample users.csv file with 5 fields. Make sure you include the header line as the first record.
login,email,firstName,lastName,groupId
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
                Add-OktaGroupMember $user.groupId $oktaUser.id
            } catch {
                $message = "Invalid group."
            }
        }
        $importedUsers += [PSCustomObject]@{id = $oktaUser.id; login = $user.login; message = $message}
    }
    $importedUsers | Export-Csv importedUsers.csv -NoTypeInformation
    "$($users.count) users read."
}

# Read users from CSV, create them in Okta, and add to multiple groups. See also previous function.
function Import-UsersAndGroups() {
<# Sample CSV file with 5 fields. Make sure you include the header line as the first record.
login,email,firstName,lastName,groupIds
testa1@okta.com,testa1@okta.com,Test,A1,"00g5gtwaaeOe7smEF0h7;00g5gtwaaeOe7smFF0h7"
testa2@okta.com,testa2@okta.com,Test,A2,"00g5gtwaaeOe7smEF0h7;00g5gtwaaeOe7smFF0h7"
#>
    $users = Import-Csv usersAndGroups.csv
    foreach ($user in $users) {
        $profile = @{login = $user.login; email = $user.email; firstName = $user.firstName; lastName = $user.lastName}
        $groupIds = $user.groupIds -split ";"
        $oktaUser = New-OktaUser @{profile = $profile; groupIds = $groupIds}
    }
}

# ~ 1000 users / 6 min in oktapreview.com
function New-Users($numUsers) {
    $now = Get-Date -Format "yyyyMMddHHmmss"
    for ($i = 1; $i -le $numUsers; $i++) {
        $profile = @{login="a$now$i@okta.com"; email="testuser$i@okta.com"; firstName="test"; lastName="ZExp$i"}
        try {
            $user = New-OktaUser @{profile = $profile; credentials = @{password = @{value = "Password123"}}} $false
            Write-Host $i
        } catch {
            Get-Error $_
        }
    }
}

function Get-MultipleUsers() {
    $ids = "me#jane.doe".split("#")
    foreach ($id in $ids) {
        $user = Get-OktaUser $id
    }
}

function Get-User() {
    try {
        $user = Get-OktaUser "me"
        $user
    } catch {
        Get-Error $_
    }
}

function Get-PagedUsers() {
    $totalUsers = 0
    $params = @{limit = 200}
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

function Export-Users() {
    $totalUsers = 0
    $exportedUsers = @()
    # for more filters, see https://developer.okta.com/docs/api/resources/users#list-users-with-a-filter
    $params = @{} # @{filter = 'status eq "ACTIVE"'}
    do {
        $page = Get-OktaUsers @params
        $users = $page.objects
        foreach ($user in $users) {
            $exportedUsers += [PSCustomObject]@{id = $user.id; login = $user.profile.login}
        }
        $totalUsers += $users.count
        Write-Host "$totalUsers users"
        $params = @{url = $page.nextUrl}
    } while ($page.nextUrl)
    $exportedUsers | Export-Csv exportedUsers.csv -notype
    Write-Host "$totalUsers users exported."
    Write-Host "Done."
}

function Export-UsersAndGroups() {
    $totalUsers = 0
    $exportedUsers = @()
    # for more filters, see https://developer.okta.com/docs/api/resources/users#list-users-with-a-filter
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
            $exportedUsers += [PSCustomObject]@{id = $user.id; login = $user.profile.login; groups = $groups -join ";"}
        }
        $totalUsers += $users.count
        $params = @{url = $page.nextUrl}
    } while ($page.nextUrl)
    $exportedUsers | Export-Csv exportedUsersGroups.csv -notype
    "$totalUsers users exported."
}

function Rename-Users() {
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

function Remove-DeprovisionedUsers() {
    $totalUsers = 0
    $params = @{filter = 'status eq "DEPROVISIONED"'}
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

function Remove-UsersBasedOnGroupMembership($groupId) {

# PERMANENTLY DELETE Okta Users. This won't just remove them from a group.

    $totalUsers = 0
    $params = @{id = $groupId; paged = $true}
    do {
        $page = Get-OktaGroupMember @params
        $users = $page.objects
        foreach ($user in $users) {
            Write-Host $user.profile.login
            Remove-OktaUser $user.id # First call sets user to DEPROVISIONED.
            Remove-OktaUser $user.id # Second call deletes user permanently.
        }
        $totalUsers += $users.count
        $params = @{url = $page.nextUrl; paged = $true}
    } while ($page.nextUrl)
    "$totalUsers users deleted."
}

# Zones

function New-Zone() {
    $zone = @{
        type = "IP"
        name = "test"
        gateways = @(
            @{
                type = "RANGE"
                value = "1.2.3.4"
            },
            @{
                type = "CIDR"
                value = "5.6.7.8/24"
            }
        )
    }
    New-OktaZone $zone
}

# Rate limits

# https://developer.okta.com/docs/reference/rate-limits
function Get-RateLimits() {
    $urlLimit = 1200 # this varies by URL
    $remaining = $urlLimit
    for ($i = 1; $i -le 5000; $i++) {
        $now = [DateTimeOffset]::Now.ToUnixTimeSeconds()
        if ($remaining -gt 20) {
            try {
                $page = Get-OktaUsers -filter 'profile.login eq "gabriel.sroka@lokta.com"'
                $limit = $page.limitLimit
                $remaining = $page.limitRemaining
                $reset = $page.limitReset
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


<#PSScriptInfo
.VERSION 1.1.13
.COPYRIGHT (c) 2015-2019 Gabriel Sroka. All rights reserved.
.GUID 33ca8742-b9bf-4824-9d86-605a8d627cb4
.AUTHOR Gabriel Sroka
.DESCRIPTION Call Okta API.
.PROJECTURI https://github.com/gabrielsroka/OktaAPI.psm1
#>
