// ── Log Analytics Workspace + Application Insights ───────────────────────────
param location string
param environment string
param keyVaultName string

var lawName = 'log-swap-dev'
var appiName = 'appi-swapai-dev'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: lawName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
  tags: {
    environment: environment
    project: 'swap'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appiName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    RetentionInDays: 30
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: {
    environment: environment
    project: 'swap'
  }
}

// ── Alert action group (email) ────────────────────────────────────────────────
resource alertActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-swap-oncall'
  location: 'global'
  properties: {
    groupShortName: 'SwapOncall'
    enabled: true
    emailReceivers: [
      {
        name: 'OncallEmail'
        emailAddress: 'oncall@yourdomain.com'
        useCommonAlertSchema: true
      }
    ]
  }
}

// ── Store connection string in Key Vault ──────────────────────────────────────
resource kv 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

resource appiSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: kv
  name: 'APPLICATIONINSIGHTS-CONNECTION-STRING'
  properties: {
    value: appInsights.properties.ConnectionString
  }
}

output logAnalyticsWorkspaceId string = logAnalytics.id
output appInsightsId string = appInsights.id
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output appInsightsConnectionStringSecretUri string = appiSecret.properties.secretUri
output alertActionGroupId string = alertActionGroup.id
