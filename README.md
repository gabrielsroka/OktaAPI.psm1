# OktaAPI.psm1
Call the Okta API from PowerShell -- unofficial code.

This module provides a thin wrapper around the [Okta API](https://developer.okta.com/docs/reference/). It converts to/from JSON. It supports [pagination](https://developer.okta.com/docs/reference/api-overview/#pagination) of objects and allows you to check [rate limits](https://developer.okta.com/docs/reference/rate-limits/).

It assumes you are familiar with the Okta API and using REST.

# Contents
- [Usage](#usage)
- [Installation](#installation)
- [Converting JSON to PowerShell](#converting-json-to-powershell)
- [Adding new endpoints](#adding-new-endpoints)

# Usage
```powershell
# Connect to Okta. Do this before making any other calls.
Connect-Okta "YOUR_API_TOKEN" "https://YOUR_ORG.oktapreview.com"

# Add a user to a group.
$user = Get-OktaUser "me"
$group = Get-OktaGroups "PowerShell" 'type eq "OKTA_GROUP"'
Add-OktaGroupMember $group.id $user.id

# Create a user.
$profile = @{login = $login; email = $email; firstName = $firstName; lastName = $lastName}
$user = New-OktaUser @{profile = $profile}

# Create a group.
$profile = @{name = $name; description = $description}
$group = New-OktaGroup @{profile = $profile}

# Get all users. If you have more than 200 users, you have to use pagination.
# See this page for more info:
# https://developer.okta.com/docs/reference/api-overview/#pagination
$params = @{filter = 'status eq "ACTIVE"'}
do {
    $page = Get-OktaUsers @params
    $users = $page.objects
    foreach ($user in $users) {
        # Add more properties here:
        Write-Host $user.profile.login $user.profile.email
    }
    $params = @{url = $page.nextUrl}
} while ($page.nextUrl)
```

See [CallOktaAPI.ps1](CallOktaAPI.ps1) for more examples.

There are functions for Apps, Events, Factors, Groups, IdPs, Logs, Roles, Schemas, Users and Zones. And you can [add your own](#adding-new-endpoints).

# Installation
To determine which version of PowerShell you're running, see PSVersion under `$PSVersionTable`.

**To Install on PowerShell 5 or newer**

```powershell
Install-Module OktaAPI # [1]

Install-Script CallOktaAPI # [2]
```
CallOktaAPI.ps1 has sample code. Replace `YOUR_API_TOKEN` and `YOUR_ORG` with your values or use OktaAPISettings.ps1.

[1] https://www.powershellgallery.com/packages/OktaAPI <br>
[2] https://www.powershellgallery.com/packages/CallOktaAPI

**To Install on PowerShell 4 or older**

1. `$env:PSModulePath` contains a list of folders where modules are located (e.g., `C:\Users\Administrator\Documents\WindowsPowerShell\Modules`). 
Create a new folder in a folder in your module path called OktaAPI (e.g., `C:\Users\Administrator\Documents\WindowsPowerShell\Modules\OktaAPI`).
2. Copy OktaAPI.psm1 to the new folder: Modules\OktaAPI
3. Copy CallOktaAPI.ps1. It has sample code. Replace `YOUR_API_TOKEN` and `YOUR_ORG` with your values or use OktaAPISettings.ps1.

**Might I also suggest an IDE and debugging tools**

- [Visual Studio Code](https://code.visualstudio.com) and the [PowerShell Extension](https://code.visualstudio.com/docs/languages/powershell) (on Windows, [macOS](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-macos), or Linux). See also [Using VS Code for PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/components/vscode/using-vscode).
- [PowerShell ISE](https://docs.microsoft.com/en-us/powershell/scripting/components/ise/introducing-the-windows-powershell-ise) (Windows-only). It comes pre-installed with most Windows versions (including Server). It's basic, but better than the command-line. It's in maintenance mode and no new features are likely to be added, so you might consider Visual Studio Code.
- [Fiddler](https://www.telerik.com/download/fiddler) - web debugging proxy.

# Converting JSON to PowerShell
Most Okta API calls come with sample `curl` commands with blocks of JSON. To convert from JSON to PowerShell:
* Change `{` to `@{`
* Change `:` to `=`
* Change `,` to `;` or use a line break instead
* Change `[` to `@(`, and `]` to `)`
* Change `true`, `false` and `null` to `$true`, `$false` and `$null`

Here is an example from [Assign User to App](https://developer.okta.com/docs/reference/api/apps/#assign-user-to-application-for-sso):

**JSON**
```json
{
  "id": "00ud4tVDDXYVKPXKVLCO",
  "scope": "USER",
  "credentials": {
    "userName": "user@example.com",
    "password": {
      "value": "correcthorsebatterystaple"
    }
  }
}
```

**PowerShell**
```powershell
@{
  id = "00ud4tVDDXYVKPXKVLCO"
  scope = "USER"
  credentials = @{
    userName = "user@example.com"
    password = @{
      value = "correcthorsebatterystaple"
    }
  }
}
```

# Adding new endpoints
To add a new endpoint, check the documentation for the [HTTP verb](https://developer.okta.com/docs/reference/api-overview/#http-verbs) (e.g. `GET`, `POST`, `PUT`, `DELETE`) and URL, and convert it into a corresponding PowerShell call.

For example, the documentation for [Get User](https://developer.okta.com/docs/reference/api/users/#get-user) says:
```
GET /api/v1/users/${id}
```

The PowerShell code is:
```powershell
function Get-OktaUser($id) {
    Invoke-Method GET "/api/v1/users/$id"
}
```

See [Modules/OktaAPI.psm1](Modules/OktaAPI.psm1) for more examples.
