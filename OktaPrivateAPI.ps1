# updated 2021-03-12

# Call Okta APIs using WebSession (cookies) and xsrfToken -- just like a browser. SSWS API Token is not needed.

### CAUTION: Code to call private APIs is not supported by Okta. Private APIs can change at any time.
###          Test in a dev or oktapreview tenant before trying this in production.

# This will work with users who have Push MFA.

# This won't work if Apps > Apps > "Okta Admin Console" > Sign On Policy > MFA is enabled for the user.

# Change the following lines, then see below for username and password.

$baseUrl = "https://XXX.oktapreview.com"
$defaultUsername = "XXX"
$dirId = "XXX"
$dirType = "active_directory" # "active_directory" or "ldap_sun_one" for LDAP
$fullImport = $false # $true or $false

# For batch mode, set username and password. Or use interactive mode below.
#$username = "XXX"
#$password = "XXX"

# For interactive mode, user will be prompted for username and password.
if ($username -eq $null) {
    $creds = Get-Credential $defaultUsername -Message "Okta Sign in"
    $username = $creds.UserName
    $password = $creds.GetNetworkCredential().Password
}

$adminBaseUrl = $baseUrl -replace '\.okta','-admin.okta'

$userAgent = "okta-api-powershell/0.1"


# Main code - sign in to Okta

function Main() {
    # $userXsrfToken is required for calls to the public or private APIs.
    if ($userXsrfToken -eq $null) {
        Write-Progress "Signing in to Okta"
        $script:userXsrfToken = Connect-OktaXsrf $username $password
    }

    # $adminXsrfToken is only required for calls to the private (admin) API.
    if ($adminXsrfToken -eq $null) {
        Write-Progress "Signing in to Okta Admin"
        $script:adminXsrfToken = Connect-OktaAdminXsrf
    }


    # Call Sample code

    Get-OktaAppSignOnPoliciesHtml
    #Get-OktaAppSignOnPoliciesCsv

    # New-OktaAppSignOnPolicy

<#
    if ($dirId -eq "XXX") {
        Write-Host "Add one of these Dir IDs to your script, on line 16:"
        Get-OktaDirs
    } else {
        ImportFrom-Dir
    }
#>

    #New-Notification "test 1025"

    # Get-Instructions "0oa57xgaoeoUBn0mq0h7"

    # Disable-Ldap "olsjh22yqxMvMT62M0h7"
    # Enable-Ldap "olsjh22yqxMvMT62M0h7"

    #Demaster-User "00u6d6spqaBIj6Oz30h7"

    # Get-OktaAppNotes

    # Refresh-Data

    # Get-User

    # Get-MFAUsage

    # Get-CurrentAssignments
}


# Sample code

function Get-OktaAppSignOnPoliciesHtml() {
    $zones = Invoke-OktaXsrfMethod GET "/api/v1/zones"
    $zoneHash = @{}
    foreach ($zone in $zones) {
        $zoneHash[$zone.id] = $zone.name
    }

#$script:allApps = @() # Clear cache (for debugging purposes).

    $start = Get-Date
    Write-Host $start
    if ($script:allApps.count -eq 0) {
        $script:allApps =  @()
        $params = @{url = "/api/v1/apps"} # ?q=a api
        do {
            $page = Invoke-OktaPagedMethod @params
            $apps = $page.objects
            foreach ($app in $apps) {
                Write-Host $app.label
                $url = "$adminBaseUrl/admin/app/instance/$($app.id)/app-sign-on-policy-list"
                $response = Invoke-WebRequest $url -WebSession $session
                # ParsedHtml and AllElements won't work on PowerShell 6.
                $policy = $response.ParsedHtml.getElementById("policy-list").innerHTML -replace ' style="WIDTH: .*px"',''
                $policy = $policy -replace '<th>Actions</th>','<th></th>' -replace 'Not editable',''
                $policy = $policy -replace "<form .*</form>",'' -replace "<a .*</a>",''
                
                $rules = $response.ParsedHtml.getElementsByClassName("appSignOnRule")
                foreach ($rule in $rules) {
                    $ruleId = $rule.id.substring(5)
                    if ($ruleId) {
                        $ruleUrl = "$adminBaseUrl/admin/policy/app-sign-on-rule/$ruleId"
                        $ruleRes = Invoke-WebRequest $ruleUrl -WebSession $session
                        $zoneId = $ruleRes.ParsedHtml.getElementById("appsignonrule.includedZoneIdString").value
                        if ($zoneId) {
                            $policy = $policy -replace "In zone","In zone: $($zoneHash[$zoneId])"
                        }
                        break
                    }
                }

                $script:allApps += @{
                    id = $app.id
                    name = $app.name
                    label = $app.label
                    signOnMode = $app.signOnMode
                    policy = "<table>$policy</table>"
                }
            }
            $params = @{url = $page.nextUrl}
        } while ($page.nextUrl)
        Write-Host (Get-Date)
        "$($allApps.count) apps found."
    }

    $appPolicies = @()
    foreach ($app in $script:allApps) {
        $appPolicies += "<tr><td>$($app.id)<td>$($app.name)<td>$($app.label)<td>$($app.signOnMode)<td>$($app.policy)"
    }
    $html = "<html><head><title>App Sign On Policies</title><style>body {font-family: sans-serif;}`n" +
        "table {border-collapse: collapse;}`n" +
        "th {text-align: left; padding: 4px; background-color: #eee; font-weight: normal;}`n" +
        "td {vertical-align: top; padding: 4px;}`n" +
        "ul {list-style-type: none;}`n" +
        "h3 {font-weight: normal; text-align: center; background-color: #eee;}`n" +
        ".policy-rule-summary-col {float: left; width: 345px;}`n" +
        ".policy-rule {border-top: 1px lightgrey solid;}</style></head>`n" +
        "<body><h1>App Sign On Policies</h1>Exported on $start<br>$($allApps.count) apps<br><br>`n" +
        "<table><tr><th>id<th>Name<th>Label<th>Sign On Mode<th>Sign On Policy`n" + ($appPolicies -join "`n") + 
        "</table></body></html>"
    $html > AppSignOnPolicies.html
}

function Get-OktaAppSignOnPoliciesCsv() {
    $totalApps = 0
    $appPolicies =  @()
    $params = @{url = "/api/v1/apps"}
    do {
        $page = Invoke-OktaPagedMethod @params
        $apps = $page.objects
        foreach ($app in $apps) {
            Write-Host $app.label
            $url = "$adminBaseUrl/admin/app/instance/$($app.id)/app-sign-on-policy-list"
            $response = Invoke-WebRequest $url -WebSession $session
            # ParsedHtml and AllElements won't work on PowerShell 6.
            $rows = $response.ParsedHtml.getElementsByTagName("tr")
            $ps = @()
            foreach ($row in $rows) {
                $ps += $row.innerText
            }
            $policies = $ps -join "`n`n"
            $appPolicies += [PSCustomObject]@{
                id = $app.id
                name = $app.name
                label = $app.label
                policies = $policies
            }
        }
        $totalApps += $apps.count
        $params = @{url = $page.nextUrl}
    } while ($page.nextUrl)
    $appPolicies | Export-Csv AppSignOnPolicies.csv -notype
    "$totalApps apps found."
}

function New-OktaAppSignOnPolicy() {
    $body = @{
        _xsrfToken = $script:adminXsrfToken
        appInstanceId = '0oa9th7tamUCYSS7x0h7'
        name = 'PowerShell Policy 6'
    }
    $headers = @{"Content-Type" = "application/x-www-form-urlencoded"}
    $response = Invoke-WebRequest "$adminBaseUrl/admin/policy/app-sign-on-rule" -Method POST -WebSession $session -Body $body -Headers $headers
    ConvertFrom-SafeJson $response.content
}

# This should work with SSWS.
function New-Notification($message) {
    $body = @{
        message = $message
        target = "GROUPS_AND_USERS" # or EVERYONE
        users  = @("00u4i04zqjEWyt4TW0h7")
        groups = @()
    } | ConvertTo-Json -Compress -depth 100
    $headers = @{"Accept" = "application/json"; "Content-Type" = "application/json"}
    Invoke-OktaAdminXsrfMethod POST "/api/internal/admin/notification" $body $headers
}

function Get-MFAUsage() {
    $url = "$adminBaseUrl/reports/user/mfa/csv_download"
    Invoke-WebRequest $url -WebSession $session -OutFile mfa_usage.csv
}

function Get-CurrentAssignments() {
    # $today = Get-Date -Format "MM/dd/yyyy"
    $startDate = [Web.HttpUtility]::UrlEncode("01/15/2020")
    $endDate = [Web.HttpUtility]::UrlEncode("01/15/2020")
    $url = "$adminBaseUrl/reports/app/access/csv_download?startDate=$startDate&endDate=$endDate"
    Invoke-WebRequest $url -WebSession $session -OutFile current_assignments.csv
}

function ImportFrom-Dir() {
    Write-Progress "Importing from $dirType"
    $status = Import-Dir
    Write-Host "Imported" $dirType
    $status
    
    # Out-GridView doesn't work in PowerShell 6.
    #$status | Out-GridView -Title "Import"
}

function Get-OktaDirs($q = $dirType) {
    $apps = Invoke-OktaRestMethod GET "/api/v1/apps?q=$q"
    $dirs = @()
    foreach ($app in $apps) {
        $dirs += [PSCustomObject]@{id = $app.id; label = $app.label}
    }
    $dirs
}

function Get-Instructions($appid) {
    Write-Progress "Getting WS-Fed Instructions"
    $response = Get-WSFedInstructions $appid
    # ParsedHtml and AllElements won't work on PowerShell 6.
    $textareas = $response.AllElements | Where TagName -eq "textarea"
    $ASPNET35 = 2 # 0 = metadata, 1 = ASP.NET 4.5, 2 = ASP.NET 3.5/4.0
    $textareas[$ASPNET35].innerText

    # ParsedHtml is sometimes buggy and pops open an IE window!!! Use AllElements.
    #$response.ParsedHtml.getElementsByTagName("textarea")[2].innerText
}

function Refresh-Data() {
    Write-Progress "Refreshing app data"
    $appNames = Refresh-AppData
    Write-Host "Success! Downloading application information for $appNames."
}

function New-User() {
    Write-Progress "Creating user"
    $profile = @{login = "test6812@test.com"; email = "test@test.com"; firstName = "First"; lastName = "Last"}
    $password = "Password123"
    $user = @{profile = $profile; credentials = @{password = @{value = $password}}}
    New-OktaXsrfUser $user
}

function Get-User() {
    $user = Get-OktaXsrfUser "me"
    $user.id
}

function Get-OktaAppNotes() {
    $totalApps = 0
    $appNotes =  @()
    $params = @{url = "/api/v1/apps"}
    do {
        $page = Invoke-OktaPagedMethod @params
        $apps = $page.objects
        foreach ($app in $apps) {
            Write-Host $app.label
            $url = "$adminBaseUrl/admin/app/$($app.name)/instance/$($app.id)/settings/general"
            $response = Invoke-WebRequest $url -WebSession $session
            # ParsedHtml and AllElements won't work on PowerShell 6.
            $endUserAppNotes =  $response.ParsedHtml.getElementById("settings.enduserAppNotes").innerText
            $adminAppNotes =  $response.ParsedHtml.getElementById("settings.adminAppNotes").innerText        
            $appNotes += [PSCustomObject]@{
                id = $app.id
                name = $app.name
                label = $app.label
                endUserAppnotes = $endUserAppNotes
                adminAppNotes = $adminAppNotes
            }
        }
        $totalApps += $apps.count
        $params = @{url = $page.nextUrl}
    } while ($page.nextUrl)
    $appNotes | Export-Csv AppNotes.csv -notype
    "$totalApps apps found."
}


# Get XSRF token.

function Connect-OktaXsrf($username, $password) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    # Sign in to Okta. Keep $session (cookies), and get user xsrfToken.
    $body =  @{username = $username; password = $password}
    $auth = Invoke-OktaRestMethod POST "/api/v1/authn" $body $true
    if (-not $auth) {
        write-host "invalid login"
        throw
    }
    if ($auth.status -eq "MFA_REQUIRED") {
        $push = $auth._embedded.factors | where factorType -eq "push"
        do {
            Write-Progress "Waiting on push MFA"
            $body = @{stateToken = $auth.stateToken}
            $auth = Invoke-OktaRestMethod POST $push._links.verify.href $body
            if ($auth.factorResult -eq "WAITING") {
                Start-Sleep -s 4
            } elseif ($auth.factorResult -eq "REJECTED" -or $auth.factorResult -eq "TIMEOUT") {
                Write-Host "Push rejected"
                throw
            }
        } until ($auth.status -eq "SUCCESS")
    }

    $sessionToken = $auth.sessionToken
    $response = Invoke-WebRequest "$baseUrl/login/sessionCookieRedirect?token=$sessionToken&redirectUrl=/" -WebSession $session
    Get-XsrfToken $response
}

function Connect-OktaAdminXsrf() {
    # Get admin login token.
    $response = Invoke-WebRequest "$baseUrl/home/admin-entry" -WebSession $session
    if ($response.content -match '"token":\["(.*)"\]') {
        $body = @{token = $matches[1]}
        # Use token to sign in to Okta Admin app, and get admin xsrfToken.
        $headers = @{"Content-Type" = "application/x-www-form-urlencoded"}
        $response = Invoke-WebRequest "$adminBaseUrl/admin/sso/request" -Method POST -WebSession $session -Body $body -Headers $headers
    #} elseif ($response.content -match "stateToken = '(.*?)'") {
    #    $body = @{token = $matches[1]}
    }

    $token = Get-XsrfToken $response
    if (-not $token) {
        Write-Host "Connect-OktaAdminXsrf: token not found. Go to Apps > Apps > Okta Admin Console > Sign On Policy, and disable Multifactor."
        throw
    }
    $token
}

function Get-XsrfToken($response) {
    if ($response.content -match '<span.* id="_xsrfToken">(.*)</span>') {
        $matches[1]
    }

    # ParsedHtml and AllElements are sometimes buggy and pop open an IE window!!! does -UseBasicParsing help?
    #$response.ParsedHtml.getElementById("_xsrfToken").innerText
    #$response.AllElements.FindById("_xsrfToken").innerText
}


# Use XSRF token.

function Import-Dir() {
    $body = @{
        fullImport = $fullImport.ToString().ToLower()
        _xsrfToken = $adminXsrfToken
    }
    $headers = @{"Content-Type" = "application/x-www-form-urlencoded"}
    $job = Invoke-OktaAdminXsrfMethod POST "/admin/user/import/$dirType/$dirId/start" $body -Headers $headers
    $jobId = $job.modelMap.jobId
    do {
        $jobListStatus = Invoke-OktaAdminXsrfMethod GET "/joblist/status?jobs=$jobId"
        $status = $jobListStatus.jobList.jobList
        if ($status.status -eq "COMPLETED") {
            break
        } else {
            $text = $status.statusText
            if ($text -eq "") {$text = "..."}
            Write-Progress $status.localizedMessage -Status $text -Percent $status.currentStep
            Start-Sleep -Seconds 2
        }
    } while ($true)
    $jobStatus = Invoke-OktaAdminXsrfMethod GET "/job/status?jobid=$jobId"
    $status = $jobStatus.job
    @(
        [PSCustomObject]@{Step = "Scanned";   Users = $status.usersScanned;   Groups = $status.groupsScanned}
        [PSCustomObject]@{Step = "Imported";  Users = $status.usersAdded;     Groups = $status.groupsAdded}
        [PSCustomObject]@{Step = "Updated";   Users = $status.usersUpdated;   Groups = $status.groupsUpdated}
        [PSCustomObject]@{Step = "Unchanged"; Users = $status.usersUnchanged; Groups = $status.groupsUnchanged}
        [PSCustomObject]@{Step = "Removed";   Users = $status.usersRemoved;   Groups = $status.groupsRemoved}
    )
}

function Refresh-AppData() {
    # Apps > Apps > Refresh App Data.
    $apps = Invoke-OktaAdminXsrfMethod POST "/admin/org/app/download"
    $apps.appDisplayNames -join ', '
}

function Demaster-User($userid) {
    $reset = "no" # yes or no
    Invoke-OktaAdminXsrfMethod POST "/admin/user/demasteruser/${userid}?reset=$reset"
    # see also /admin/user/demaster for bulk
}

function Disable-Ldap($ldapId) {
    Invoke-OktaAdminXsrfMethod POST "/admin/app/ldapi/deactivate/$ldapId"
}

function Enable-Ldap($ldapId) {
    Invoke-OktaAdminXsrfMethod POST "/admin/app/ldapi/activate/$ldapId"
}

# This function requires PowerShell 6.
function Upload-AppLogo($appid, $FilePath) {
    $url = "$adminBaseUrl/admin/app/bookmark/instance/$appId/edit-link"
    $form = @{
        file = Get-Item -Path $FilePath
        linkId = "1280"
        _xsrfToken = $adminXsrfToken
    }
     
    $response = Invoke-RestMethod $url -Method POST -WebSession $session -form $form
}

# This function requires PowerShell 6.
function Upload-OktaLogo($FilePath) {
    $url = "$adminBaseUrl/admin/settings/customize/logo/upload"
    $form = @{
        bytes = Get-Item -Path $FilePath
        _xsrfToken = $adminXsrfToken
    }
     
    $response = Invoke-RestMethod $url -Method POST -WebSession $session -form $form
}

function Get-WSFedInstructions($appid) {
    $url = "$adminBaseUrl/app/template_wsfed/$appid/setup/help/WS_FEDERATION/instructions"
    Invoke-WebRequest $url -WebSession $session
}

function New-OktaXsrfUser($user) {
    Invoke-OktaXsrfMethod POST "/api/v1/users" $user
}

function Get-OktaXsrfUser($userId) {
    Invoke-OktaXsrfMethod GET "/api/v1/users/$userId"
}


# Core functions

function Invoke-OktaXsrfMethod($method, $path, $body) {
    # Use $session and X-Okta-XsrfToken -- SSWS API token is not needed.
    $headers = @{
        "Accept" = "application/json"
        "Content-Type" = "application/json"
        "X-Okta-XsrfToken" = $userXsrfToken
    }
    $url = $baseUrl + $path
    if ($body) {
        $jsonBody = $body | ConvertTo-Json -compress -depth 100 # max depth is 100. pipe works better than InputObject
    }
    Invoke-RestMethod $url -Method $method -WebSession $session -Headers $headers -Body $jsonBody -UserAgent $userAgent
}

function Invoke-OktaAdminXsrfMethod($method, $path, $body, $headers) {
    if (-not $headers) {
        $headers = @{}
    }
    $headers["X-Okta-XsrfToken"] = $adminXsrfToken
    $url = $adminBaseUrl + $path
    $response = Invoke-WebRequest $url -Method $method -WebSession $session -Headers $headers -Body $body
    ConvertFrom-SafeJson $response.Content
}

function Invoke-OktaRestMethod($method, $url, $body, $start) {
    # Use $session -- SSWS API token is not needed.
    if ($url -notMatch '^http') {$url = $baseUrl + $url}
    if ($body) {
        $jsonBody = $body | ConvertTo-Json -compress -depth 100 # max depth is 100. pipe works better than InputObject
    }
    $headers = @{"Accept" = "application/json"; "Content-Type" = "application/json"}
    if ($start) {
        Invoke-RestMethod $url -Method $method -SessionVariable script:session  -Headers $headers -Body $jsonBody -UserAgent $userAgent
    } else {
        Invoke-RestMethod $url -Method $method -WebSession $session -Headers $headers -Body $jsonBody -UserAgent $userAgent
    }
}

function Invoke-OktaPagedMethod($url) {
    if ($url -notMatch '^http') {$url = $baseUrl + $url}
    $response = Invoke-WebRequest $url -Method GET -WebSession $session
    $links = @{}
    if ($response.Headers.Link) { # Some searches (eg List Users with Search) do not support pagination.
        foreach ($header in $response.Headers.Link.split(",")) {
            if ($header -match '<(.*)>; rel="(.*)"') {
                $links[$matches[2]] = $matches[1]
            }
        }
    }
    @{objects = ConvertFrom-Json $response.content
      nextUrl = $links.next
      response = $response
      limitLimit = [int][string]$response.Headers.'X-Rate-Limit-Limit'
      limitRemaining = [int][string]$response.Headers.'X-Rate-Limit-Remaining' # how many calls are remaining
      limitReset = [int][string]$response.Headers.'X-Rate-Limit-Reset' # when limit will reset, see also [DateTimeOffset]::FromUnixTimeSeconds(limitReset)
    }
}

function ConvertFrom-SafeJson($text) {
    if ($text -match "^while") {
        # $text has a prefix to prevent JSON hijacking. We have to remove the prefix.
        $prefix = "while(1){};"
        $text = $text.Substring($prefix.Length)
    }
    ConvertFrom-Json $text
}


# This should be the last line in the file.
Main
