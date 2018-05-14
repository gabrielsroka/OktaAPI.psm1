# Contents
- [OktaAPI.psm1 overview](#oktaapipsm1-overview)
- [Sample Code](#sample-code)
- [Installation](#installation)
- [Adding new endpoints](#adding-new-endpoints)
- [Converting JSON to PowerShell](#converting-json-to-powershell)

# OktaAPI.psm1 overview
Unofficial code. Call Okta API from PowerShell.

This module provides a very thin wrapper around the [Okta API](https://developer.okta.com/documentation/). It converts to/from JSON. It allows you to fetch [pages](https://developer.okta.com/docs/api/getting_started/design_principles#pagination) of objects and check [rate limits](https://developer.okta.com/docs/api/getting_started/rate-limits).

It assumes you are familiar with the Okta API and using REST.

# Sample Code
```powershell
Connect-Okta "YOUR_API_TOKEN" "https://YOUR_ORG.oktapreview.com"

$user = Get-OktaUser "me"
$group = Get-OktaGroups "PowerShell" 'type eq "OKTA_GROUP"'
Add-OktaGroupMember $group.id $user.id
```

See CallOktaAPI.ps1 for more samples.

# Installation
To determine which version of PowerShell you're running, see PSVersion under `$PSVersionTable`.

To Install on PowerShell 5:

1. https://www.powershellgallery.com/packages/OktaAPI
2. https://www.powershellgallery.com/packages/CallOktaAPI
3. CallOktaAPI.ps1 has sample code. Replace YOUR_API_TOKEN and YOUR_ORG with your values or use OktaAPISettings.ps1.

To Install on PowerShell 4 or older:

1. `$env:PSModulePath` contains a list of folders where modules live (e.g., C:\Users\Administrator\Documents\WindowsPowerShell\Modules). 
Create a new folder in a folder in your module path called OktaAPI (e.g., C:\Users\Administrator\Documents\WindowsPowerShell\Modules\OktaAPI).
2. Copy OktaAPI.psm1 to the new folder: Modules\OktaAPI
3. Copy CallOktaAPI.ps1. It has sample code. Replace YOUR_API_TOKEN and YOUR_ORG with your values or use OktaAPISettings.ps1.

# Adding new endpoints

To add a new endpoint, check the documentation for the HTTP method (e.g. `GET`/`POST`/`PUT`/`DELETE`) and URL, and convert it into a corresponding PowerShell call.

For example, the documentation for [Get User](https://developer.okta.com/docs/api/resources/users#get-user) says:
```
GET /api/v1/users/${id}
```

The PowerShell code is:
```powershell
function Get-OktaUser($id) {
    Invoke-Method GET "/api/v1/users/$id"
}
```

See OktaAPI.psm1 for more examples.

# Converting JSON to PowerShell

To convert from JSON to PowerShell:
* Replace `{` with `@{`
* Replace `:` with `=`
* Replace `,` with `;` or you can use a line break instead of `;`

Here is an example from https://developer.okta.com/docs/api/resources/apps#assign-user-to-application-for-sso

*JSON*
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

*PowerShell*
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
