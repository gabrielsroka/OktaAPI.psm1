# OktaAPI.psm1
Unofficial code. Call Okta API from PowerShell.

To Install on PowerShell 5 (see PSVersion under `$PSVersionTable`) see:

1. https://www.powershellgallery.com/packages/OktaAPI
2. https://www.powershellgallery.com/packages/CallOktaAPI
3. CallOktaAPI.ps1 has sample code. Replace YOUR_API_TOKEN and YOUR_ORG with your values.

To Install on PowerShell 4 or older:

1. `$env:PSModulePath` contains a list of folders where modules live (e.g., C:\Users\Administrator\Documents\WindowsPowerShell\Modules). 
Create a new folder in a folder in your module path called OktaAPI (e.g., C:\Users\Administrator\Documents\WindowsPowerShell\Modules\OktaAPI).
2. Copy OktaAPI.psm1 to the new folder: Modules\OktaAPI
3. Copy CallOktaAPI.ps1. It has sample code. Replace YOUR_API_TOKEN and YOUR_ORG with your values.
