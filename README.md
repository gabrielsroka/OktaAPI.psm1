# OktaAPI.psm1
Unofficial code. Call Okta API from PowerShell.

# Sample Code
```
Connect-Okta "YOUR_API_TOKEN" "https://YOUR_ORG.oktapreview.com"
Get-OktaUser me
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
