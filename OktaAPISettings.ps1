# API token comes from Okta Admin > Security > API > Create Token
# see http://developer.okta.com/docs/api/getting_started/getting_a_token.html

# Call this before calling Okta API functions. Replace YOUR_API_TOKEN and YOUR_ORG with your values.
Connect-Okta "YOUR_API_TOKEN" "https://YOUR_ORG.oktapreview.com"
