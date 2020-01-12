# With credit to https://github.com/mbegan/Okta-PSModule

# Script vars.
$headers = @{}
$baseUrl = ""
$userAgent = ""

# Call Connect-Okta before calling Okta API functions.
function Connect-Okta($token, $baseUrl) {
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

function New-OktaApp($app, $activate = $true) {
    Invoke-Method POST "/api/v1/apps?activate=$activate" $app
}

function Get-OktaApp($appid) {
    Invoke-Method GET "/api/v1/apps/$appid"
}

function Get-OktaApps($filter, $limit = 20, $expand, $url = "/api/v1/apps?filter=$filter&limit=$limit&expand=$expand&q=$q", $q) {
    Invoke-PagedMethod $url
}

function Add-OktaAppUser($appid, $appuser) {
    Invoke-Method POST "/api/v1/apps/$appid/users" $appuser
}

function Get-OktaAppUser($appid, $userid) {
    Invoke-Method GET "/api/v1/apps/$appid/users/$userid"
}

function Get-OktaAppUsers($appid, $limit = 50, $url = "/api/v1/apps/$appid/users?limit=$limit&expand=$expand", $expand) {
    Invoke-PagedMethod $url
}

function Set-OktaAppUser($appid, $userid, $appuser) {
    Invoke-Method POST "/api/v1/apps/$appid/users/$userid" $appuser
}

function Remove-OktaAppUser($appid, $userid) {
    $null = Invoke-Method DELETE "/api/v1/apps/$appid/users/$userid"
}

function Add-OktaAppGroup($appid, $groupid, $group) {
    Invoke-Method PUT "/api/v1/apps/$appid/groups/$groupid" $group
}

function Get-OktaAppGroups($appid, $limit = 20, $url = "/api/v1/apps/$appid/groups?limit=$limit&expand=$expand", $expand) {
    Invoke-PagedMethod $url
}

function Remove-OktaAppGroup($appid, $groupid) {
    $null = Invoke-Method DELETE "/api/v1/apps/$appid/groups/$groupid"
}
#endregion

#region Events - https://developer.okta.com/docs/reference/api/events

function Get-OktaEvents($startDate, $filter, $limit = 1000, $url = "/api/v1/events?startDate=$startDate&filter=$filter&limit=$limit", $paged = $false) {
    if ($paged) {
        Invoke-PagedMethod $url
    } else {
        Invoke-Method GET $url
    }
}
#endregion

#region Factors (MFA) - https://developer.okta.com/docs/reference/api/factors

function Get-OktaFactor($userid, $factorid) {
    Invoke-Method GET "/api/v1/users/$userid/factors/$factorid"
}

function Get-OktaFactors($userid) {
    Invoke-Method GET "/api/v1/users/$userid/factors"
}

function Get-OktaFactorsToEnroll($userid) {
    Invoke-Method GET "/api/v1/users/$userid/factors/catalog"
}

function Set-OktaFactor($userid, $factor, $activate = $false) {
    Invoke-Method POST "/api/v1/users/$userid/factors?activate=$activate" $factor
}

function Enable-OktaFactor($userid, $factorid, $body) {
    Invoke-Method POST "/api/v1/users/$userid/factors/$factorid/lifecycle/activate" $body
}

function Remove-OktaFactor($userid, $factorid) {
    $null = Invoke-Method DELETE "/api/v1/users/$userid/factors/$factorid"
}
#endregion

#region Groups - https://developer.okta.com/docs/reference/api/groups

function New-OktaGroup($group) {
    Invoke-Method POST "/api/v1/groups" $group
}

function New-OktaGroupRule($groupRule) {
    Invoke-Method POST "/api/v1/groups/rules" $groupRule
}

function Get-OktaGroup($id) {
    Invoke-Method GET "/api/v1/groups/$id"
}

function Get-OktaGroups($q, $filter, $limit = 200, $url = "/api/v1/groups?q=$q&filter=$filter&limit=$limit", $paged = $false) {
    if ($paged) {
        Invoke-PagedMethod $url
    } else {
        Invoke-Method GET $url
    }
}

function Get-OktaGroupMember($id, $limit = 200, $url = "/api/v1/groups/$id/users?limit=$limit", $paged = $false) {
    if ($paged) {
        Invoke-PagedMethod $url
    } else {
        Invoke-Method GET $url
    }
}

function Get-OktaGroupApps($id, $limit = 20, $url = "/api/v1/groups/$id/apps?limit=$limit") {
    Invoke-PagedMethod $url
}

function Get-OktaGroupRules($limit = 50, $url = "/api/v1/groups/rules?limit=$limit") {
    Invoke-PagedMethod $url
}

function Add-OktaGroupMember($groupid, $userid) {
    $null = Invoke-Method PUT "/api/v1/groups/$groupid/users/$userid"
}

function Remove-OktaGroupMember($groupid, $userid) {
    $null = Invoke-Method DELETE "/api/v1/groups/$groupid/users/$userid"
}
#endregion

#region IdPs - https://developer.okta.com/docs/reference/api/idps

function Get-OktaIdps($q, $type, $limit = 20, $url = "/api/v1/idps?q=$q&type=$type&limit=$limit") {
    Invoke-PagedMethod $url
}
#endregion

#region Logs - https://developer.okta.com/docs/reference/api/system-log

function Get-OktaLogs($since, $until, $filter, $q, $sortOrder = "ASCENDING", $limit = 100, $url = "/api/v1/logs?since=$since&until=$until&filter=$filter&q=$q&sortOrder=$sortOrder&limit=$limit", $convert = $true) {
    Invoke-PagedMethod $url $convert
}
#endregion

#region Roles - https://developer.okta.com/docs/reference/api/roles

function Get-OktaRoles($id) {
    Invoke-Method GET "/api/v1/users/$id/roles"
}
#endregion

#region Schemas - https://developer.okta.com/docs/reference/api/schemas

function New-OktaSchema($schema) {
    Invoke-Method POST "/api/v1/meta/schemas/user/default" $schema
}

function Get-OktaSchemas() {
    Invoke-Method GET "/api/v1/meta/schemas/user/default"
}
#endregion

#region Users - https://developer.okta.com/docs/reference/api/users

function New-OktaUser($user, $activate = $true) {
    Invoke-Method POST "/api/v1/users?activate=$activate" $user
}

function Get-OktaUser($id) {
    Invoke-Method GET "/api/v1/users/$id"
}

function Get-OktaUsers($q, $filter, $limit = 200, $url = "/api/v1/users?q=$q&filter=$filter&limit=$limit&search=$search", $search) {
    Invoke-PagedMethod $url
}

function Set-OktaUser($id, $user) {
# Only the profile properties specified in the request will be modified when using the POST method.
    Invoke-Method POST "/api/v1/users/$id" $user
}

function Get-OktaUserAppLinks($id) {
    Invoke-Method GET "/api/v1/users/$id/appLinks"
}

function Get-OktaUserGroups($id) {
    Invoke-Method GET "/api/v1/users/$id/groups"
}

function Enable-OktaUser($id, $sendEmail = $true) {
    Invoke-Method POST "/api/v1/users/$id/lifecycle/activate?sendEmail=$sendEmail"
}

function Disable-OktaUser($id) {
    $null = Invoke-Method POST "/api/v1/users/$id/lifecycle/deactivate"
}

function Set-OktaUserResetPassword($id, $sendEmail = $true) {
    Invoke-Method POST "/api/v1/users/$id/lifecycle/reset_password?sendEmail=$sendEmail"
}

function Set-OktaUserExpirePassword($id) {
    Invoke-Method POST "/api/v1/users/$id/lifecycle/expire_password"
}

function Remove-OktaUser($id) {
    $null = Invoke-Method DELETE "/api/v1/users/$id"
}
#endregion

#region Zones - https://developer.okta.com/docs/reference/api/zones

function New-OktaZone($zone) {
    Invoke-Method POST "/api/v1/zones" $zone
}

function Get-OktaZone($id) {
    Invoke-Method GET "/api/v1/zones/$id"
}

function Get-OktaZones($filter, $limit = 20, $url = "/api/v1/zones?filter=$filter&limit=$limit") {
    Invoke-PagedMethod $url
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
    @{objects = $objects
      nextUrl = $links.next
      response = $response
      limitLimit = [int][string]$response.Headers.'X-Rate-Limit-Limit'
      limitRemaining = [int][string]$response.Headers.'X-Rate-Limit-Remaining' # how many calls are remaining
      limitReset = [int][string]$response.Headers.'X-Rate-Limit-Reset' # when limit will reset, see also [DateTimeOffset]::FromUnixTimeSeconds(limitReset)
    }
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
