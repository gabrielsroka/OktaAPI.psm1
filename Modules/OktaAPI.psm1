# With credit to https://github.com/mbegan/Okta-PSModule

# Script vars.
$headers = @{}
$baseUrl = ""
$userAgent = ""

# Call Connect-Okta before calling Okta API functions.
function Connect-Okta {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$token,
        [Parameter(Mandatory = $true)]
        [string]$baseUrl
    )
    $script:headers = @{"Authorization" = "SSWS $token"; "Accept" = "application/json"; "Content-Type" = "application/json"}
    $script:baseUrl = $baseUrl

    $module = Get-Module OktaAPI
    $modVer = $module.Version.ToString()
    $psVer = $PSVersionTable.PSVersion

    $osDesc = [Runtime.InteropServices.RuntimeInformation]::OSDescription
    $osVer = [Environment]::OSVersion.Version.ToString()
    if ($osDesc -match "Windows") {
        $os = "Windows"
    } elseif ($osDesc -match "Linux") {
        $os = "Linux"
    } else { # "Darwin" ?
        $os = "MacOS"
    }

    $script:userAgent = "okta-api-powershell/$modVer powershell/$psVer $os/$osVer"
    # $script:userAgent = "OktaAPIWindowsPowerShell/0.1" # Old user agent.
    # default: "Mozilla/5.0 (Windows NT; Windows NT 6.3; en-US) WindowsPowerShell/5.1.14409.1012"

    # see https://www.codyhosterman.com/2016/06/force-the-invoke-restmethod-powershell-cmdlet-to-use-tls-1-2/
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

#region Apps - https://developer.okta.com/docs/reference/api/apps

function New-OktaApp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$app,
        [Parameter(Mandatory = $false)]
        [boolean]$activate = $true
    )
    Invoke-Method POST "/api/v1/apps?activate=$activate" $app
}

function Get-OktaApp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$appid
    )
    Invoke-Method GET "/api/v1/apps/$appid"
}

function Get-OktaApps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$filter,
        [Parameter(Mandatory = $false)]
        [int]$limit = 20,
        [Parameter(Mandatory = $false)]
        [string]$expand,
        [Parameter(Mandatory = $false)]
        [string]$q
    )
    Invoke-PagedMethod "/api/v1/apps?filter=$filter&limit=$limit&expand=$expand&q=$q"
}

function Add-OktaAppUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$appid,
        [Parameter(Mandatory = $true)]
        [string]$appuser
    )
    Invoke-Method POST "/api/v1/apps/$appid/users" $appuser
}

function Get-OktaAppUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$appid,
        [Parameter(Mandatory = $true)]
        [string]$userid
    )
    Invoke-Method GET "/api/v1/apps/$appid/users/$userid"
}

function Get-OktaAppUsers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$appid,
        [Parameter(Mandatory = $false)]
        [int]$limit = 50,
        [Parameter(Mandatory = $false)]
        [string]$q
    )
    Invoke-PagedMethod "/api/v1/apps/$appid/users?limit=$limit&q=$q"
}

function Set-OktaAppUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$appid,
        [Parameter(Mandatory = $true)]
        [string]$userid,
        [Parameter(Mandatory = $true)]
        [string]$appuser
    )
    Invoke-Method POST "/api/v1/apps/$appid/users/$userid" $appuser
}

function Remove-OktaAppUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$appid,
        [Parameter(Mandatory = $true)]
        [string]$userid,
        [Parameter(Mandatory = $false)]
        [boolean]$sendEmail = $false
    )
    $null = Invoke-Method DELETE "/api/v1/apps/$appid/users/$userid?sendEmail=$sendEmail"
}

function Add-OktaAppGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$appid,
        [Parameter(Mandatory = $true)]
        [string]$groupid,
        [Parameter(Mandatory = $true)]
        [string]$group
    )
    Invoke-Method PUT "/api/v1/apps/$appid/groups/$groupid" $group
}

function Get-OktaAppGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$appid,
        [Parameter(Mandatory = $false)]
        [int]$limit = 20
    )
    Invoke-PagedMethod "/api/v1/apps/$appid/groups?limit=$limit"
}

function Remove-OktaAppGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$appid,
        [Parameter(Mandatory = $true)]
        [string]$groupid
    )
    $null = Invoke-Method DELETE "/api/v1/apps/$appid/groups/$groupid"
}
#endregion

#region Events - https://developer.okta.com/docs/reference/api/events

function Get-OktaEvents {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$startDate,
        [Parameter(Mandatory = $false)]
        [string]$filter,
        [Parameter(Mandatory = $false)]
        [int]$limit = 1000,
        [Parameter(Mandatory = $false)]
        [boolean]$paged = $false
    )
    if ($paged) {
        Invoke-PagedMethod "/api/v1/events?startDate=$startDate&filter=$filter&limit=$limit"
    } else {
        Invoke-Method GET "/api/v1/events?startDate=$startDate&filter=$filter&limit=$limit"
    }
}
#endregion

#region Factors (MFA) - https://developer.okta.com/docs/reference/api/factors

function Get-OktaFactor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$userid,
        [Parameter(Mandatory = $true)]
        [string]$factorid
    )
    Invoke-Method GET "/api/v1/users/$userid/factors/$factorid"
}

function Get-OktaFactors {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$userid
    )
    Invoke-Method GET "/api/v1/users/$userid/factors"
}

function Get-OktaFactorsToEnroll {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$userid
    )
    Invoke-Method GET "/api/v1/users/$userid/factors/catalog"
}

function Set-OktaFactor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$userid,
        [Parameter(Mandatory = $true)]
        [string]$factor,
        [Parameter(Mandatory = $false)]
        [boolean]$activate = $false
    )
    Invoke-Method POST "/api/v1/users/$userid/factors?activate=$activate" $factor
}

function Enable-OktaFactor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$userid,
        [Parameter(Mandatory = $true)]
        [string]$factorid,
        [Parameter(Mandatory = $true)]
        [string]$body
    )
    Invoke-Method POST "/api/v1/users/$userid/factors/$factorid/lifecycle/activate" $body
}

function Remove-OktaFactor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$userid,
        [Parameter(Mandatory = $true)]
        [string]$factorid
    )
    $null = Invoke-Method DELETE "/api/v1/users/$userid/factors/$factorid"
}
#endregion

#region Groups - https://developer.okta.com/docs/reference/api/groups

function New-OktaGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$group
    )
    Invoke-Method POST "/api/v1/groups" $group
}

function New-OktaGroupRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$groupRule
    )
    Invoke-Method POST "/api/v1/groups/rules" $groupRule
}

function Get-OktaGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$id
    )
    Invoke-Method GET "/api/v1/groups/$id"
}

function Get-OktaGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$q,
        [Parameter(Mandatory = $false)]
        [string]$filter,
        [Parameter(Mandatory = $false)]
        [int]$limit = 200,
        [Parameter(Mandatory = $false)]
        [string]$paged = $false
    )
    if ($paged) {
        Invoke-PagedMethod "/api/v1/groups?q=$q&filter=$filter&limit=$limit"
    } else {
        Invoke-Method GET "/api/v1/groups?q=$q&filter=$filter&limit=$limit"
    }
}

function Remove-OktaGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$id
    )
    $null = Invoke-Method DELETE "/api/v1/groups/$id"
}

function Get-OktaGroupMember {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$id,
        [Parameter(Mandatory = $false)]
        [int]$limit = 200,
        [Parameter(Mandatory = $false)]
        [string]$paged = $false
    )
    if ($paged) {
        Invoke-PagedMethod "/api/v1/groups/$id/users?limit=$limit"
    } else {
        Invoke-Method GET "/api/v1/groups/$id/users?limit=$limit"
    }
}

function Get-OktaGroupApps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$id,
        [Parameter(Mandatory = $false)]
        [int]$limit = 20
    )
    Invoke-PagedMethod "/api/v1/groups/$id/apps?limit=$limit"
}

function Get-OktaGroupRules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$limit = 50
    )
    Invoke-PagedMethod "/api/v1/groups/rules?limit=$limit"
}

function Enable-OktaGroupRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ruleid
    )
    Invoke-Method POST "/api/v1/groups/rules/$ruleid/lifecycle/activate"
}

function Add-OktaGroupMember {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$groupid,
        [Parameter(Mandatory = $true)]
        [string]$userid
    )
    $null = Invoke-Method PUT "/api/v1/groups/$groupid/users/$userid"
}

function Remove-OktaGroupMember {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$groupid,
        [Parameter(Mandatory = $true)]
        [string]$userid
    )
    $null = Invoke-Method DELETE "/api/v1/groups/$groupid/users/$userid"
}
#endregion

#region IdPs - https://developer.okta.com/docs/reference/api/idps

function Get-OktaIdps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$q,
        [Parameter(Mandatory = $false)]
        [string]$type,
        [Parameter(Mandatory = $false)]
        [int]$limit = 20
    )
    Invoke-PagedMethod "/api/v1/idps?q=$q&type=$type&limit=$limit"
}
#endregion

#region Logs - https://developer.okta.com/docs/reference/api/system-log

function Get-OktaLogs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$since,
        [Parameter(Mandatory = $false)]
        [string]$until,
        [Parameter(Mandatory = $false)]
        [string]$filter,
        [Parameter(Mandatory = $false)]
        [string]$q,
        [Parameter(Mandatory = $false)]
        [string]$sortOrder = "ASCENDING",
        [Parameter(Mandatory = $false)]
        [int]$limit = 100,
        [Parameter(Mandatory = $false)]
        [boolean]$convert = $true
    )
    Invoke-PagedMethod "/api/v1/logs?since=$since&until=$until&filter=$filter&q=$q&sortOrder=$sortOrder&limit=$limit" $convert
}
#endregion

#region Roles - https://developer.okta.com/docs/reference/api/roles

function Get-OktaRoles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$id
    )
    Invoke-Method GET "/api/v1/users/$id/roles"
}
#endregion

#region Schemas - https://developer.okta.com/docs/reference/api/schemas

function New-OktaSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$schema
    )
    Invoke-Method POST "/api/v1/meta/schemas/user/default" $schema
}

function Get-OktaSchemas {
    [CmdletBinding()]
    param()
    Invoke-Method GET "/api/v1/meta/schemas/user/default"
}
#endregion

#region Users - https://developer.okta.com/docs/reference/api/users

function New-OktaUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$user,
        [Parameter(Mandatory = $false)]
        [boolean]$activate = $true
    )
    Invoke-Method POST "/api/v1/users?activate=$activate" $user
}

function Get-OktaUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$id
    )
    Invoke-Method GET "/api/v1/users/$id"
}

function Get-OktaUsers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$q,
        [Parameter(Mandatory = $false)]
        [string]$filter,
        [Parameter(Mandatory = $false)]
        [int]$limit = 200,
        [Parameter(Mandatory = $false)]
        [string]$search
    )
    Invoke-PagedMethod "/api/v1/users?q=$q&filter=$filter&limit=$limit&search=$search"
}

function Set-OktaUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$id,
        [Parameter(Mandatory = $true)]
        [string]$user
    )
    # Only the profile properties specified in the request will be modified when using the POST method.
    Invoke-Method POST "/api/v1/users/$id" $user
}

function Get-OktaUserAppLinks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$id
    )
    Invoke-Method GET "/api/v1/users/$id/appLinks"
}

function Get-OktaUserGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$id,
        [Parameter(Mandatory = $false)]
        [int]$limit = 200,
        [Parameter(Mandatory = $true)]
        [boolean]$paged = $false
    )
    if ($paged) {
        Invoke-PagedMethod "/api/v1/users/$id/groups?limit=$limit"
    } else {
        Invoke-Method GET "/api/v1/users/$id/groups?limit=$limit"
    }
}

function Enable-OktaUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$id,
        [Parameter(Mandatory = $false)]
        [boolean]$sendEmail = $true
    )
    Invoke-Method POST "/api/v1/users/$id/lifecycle/activate?sendEmail=$sendEmail"
}

function Disable-OktaUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$id
    )
    $null = Invoke-Method POST "/api/v1/users/$id/lifecycle/deactivate"
}

function Set-OktaUserResetPassword {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$id,
        [Parameter(Mandatory = $false)]
        [boolean]$sendEmail = $true
    )
    Invoke-Method POST "/api/v1/users/$id/lifecycle/reset_password?sendEmail=$sendEmail"
}

function Set-OktaUserExpirePassword {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$id
    )
    Invoke-Method POST "/api/v1/users/$id/lifecycle/expire_password"
}

function Set-OktaUserUnlocked {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$id
    )
    Invoke-Method POST "/api/v1/users/$id/lifecycle/unlock"
}

function Remove-OktaUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$id
    )
    $null = Invoke-Method DELETE "/api/v1/users/$id"
}
#endregion

#region Zones - https://developer.okta.com/docs/reference/api/zones

function New-OktaZone {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$zone
    )
    Invoke-Method POST "/api/v1/zones" $zone
}

function Get-OktaZone {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$id
    )
    Invoke-Method GET "/api/v1/zones/$id"
}

function Get-OktaZones {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$filter,
        [Parameter(Mandatory = $false)]
        [int]$limit = 20
    )
    Invoke-PagedMethod "/api/v1/zones?filter=$filter&limit=$limit"
}
#endregion

#region Core functions

function Invoke-Method($method, $path, $body) {
    $url = $baseUrl + $path
    if ($body) {
        $jsonBody = $body | ConvertTo-Json -compress -depth 100 # max depth is 100. pipe works better than InputObject
        # from https://stackoverflow.com/questions/15290185/invoke-webrequest-issue-with-special-characters-in-json
        # $jsonBody = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
    }
    Invoke-RestMethod $url -Method $method -Headers $headers -Body $jsonBody -UserAgent $userAgent -UseBasicParsing
}

function Invoke-PagedMethod($url, $convert = $true) {
    $output = @()
    do {
        if ($url -notMatch '^http') {$url = $baseUrl + $url}
        $response = Invoke-WebRequest $url -Method GET -Headers $headers -UserAgent $userAgent -UseBasicParsing
        $links = @{}
        if ($response.Headers.Link) { # Some searches (eg List Users with Search) do not support pagination.
            foreach ($header in $response.Headers.Link.split(",")) {
                if ($header -match '<(.*)>; rel="(.*)"') {
                    $links[$matches[2]] = $matches[1]
                }
            }
        }
        $objects = $null
        if ($convert) {
            $objects = ConvertFrom-Json $response.content
        }
        $loopOutput = @{
            objects = $objects
            nextUrl = $links.next
            response = $response
            limitLimit = [int][string]$response.Headers.'X-Rate-Limit-Limit'
            limitRemaining = [int][string]$response.Headers.'X-Rate-Limit-Remaining' # how many calls are remaining
            limitReset = [int][string]$response.Headers.'X-Rate-Limit-Reset' # when limit will reset, see also [DateTimeOffset]::FromUnixTimeSeconds(limitReset)
        }

        $output += $loopOutput.objects
        $url = $loopOutput.nextUrl
    } while ($loopOutput.nextUrl)

    $output
}

function Invoke-OktaWebRequest($method, $path, $body) {
    $url = $baseUrl + $path
    if ($body) {
        $jsonBody = $body | ConvertTo-Json -compress -depth 100
    }
    $response = Invoke-WebRequest $url -Method $method -Headers $headers -Body $jsonBody -UserAgent $userAgent -UseBasicParsing
    @{objects = ConvertFrom-Json $response.content
      response = $response
      limitLimit = [int][string]$response.Headers.'X-Rate-Limit-Limit'
      limitRemaining = [int][string]$response.Headers.'X-Rate-Limit-Remaining' # how many calls are remaining
      limitReset = [int][string]$response.Headers.'X-Rate-Limit-Reset' # when limit will reset, see also [DateTimeOffset]::FromUnixTimeSeconds(limitReset)
    }
}

function Get-Error($_) {
    $responseStream = $_.Exception.Response.GetResponseStream()
    $responseReader = New-Object System.IO.StreamReader($responseStream)
    $responseContent = $responseReader.ReadToEnd()
    ConvertFrom-Json $responseContent
}
#endregion
