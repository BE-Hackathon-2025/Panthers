// ── Azure Static Web Apps (Standard tier) ────────────────────────────────────
param location string
param environment string

var stwaName = 'stwa-swap-${environment}'

resource staticWebApp 'Microsoft.Web/staticSites@2023-01-01' = {
  name: stwaName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    // GitHub Actions deployment is configured via the CI/CD workflow, not here
    buildProperties: {
      skipGithubActionWorkflowGeneration: true
    }
  }
  tags: {
    environment: environment
    project: 'swap'
  }
}

output staticWebAppName string = staticWebApp.name
output staticWebAppUrl string = 'https://${staticWebApp.properties.defaultHostname}'
output deploymentToken string = staticWebApp.listSecrets().properties.apiKey
