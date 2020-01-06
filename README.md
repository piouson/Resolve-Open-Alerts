# Resolve-Open-Alerts

Powershell Component for Datto RMM (queries RMM API and requires API Token).  
This is especially useful if you have collected 100s or 1000s of unresolved alerts over time and want a one-button-click-resolve for open Alerts based on Alert Priority, for example, resolve all Moderate Alerts.  

## NOTES:

- Not for batch deployment, therefore only tested on PS5  
- Requires API Token generated according to the [RMM APIv2 Docs](https://help.aem.autotask.net/en/Content/2SETUP/APIv2.htm)  
- To avoid Platform mismatch, run Component on Device in the same RMM Account with API token  
- To avoid publicly sharing API Token, create System Variable "RMMAPIKey" on target device before deploying  
