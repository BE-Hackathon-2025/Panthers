// ── App Service Plan + App Service (Linux, Python 3.11, ZIP deploy) ──────────
param location string
param environment string
param keyVaultName string
param appInsightsConnectionStringSecretUri string
param cosmosConnectionStringSecretUri string
param redisConnectionStringSecretUri string

@secure()
param b2cClientSecret string

var planName = 'plan-swap-${environment}'
var appName = 'app-swapai-backend'

// ── App Service Plan ──────────────────────────────────────────────────────────
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: planName
  location: location
  kind: 'linux'
  sku: {
    name: 'B2'
    tier: 'Basic'
  }
  properties: {
    reserved: true  // Required for Linux
  }
  tags: {
    environment: environment
    project: 'swap'
  }
}

// ── App Service ───────────────────────────────────────────────────────────────
resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: appName
  location: location
  identity: {
    type: 'SystemAssigned'  // Managed Identity for Key Vault access
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11'
      appCommandLine: 'python -m uvicorn app.main:app --host 0.0.0.0 --port 8000'
      alwaysOn: true
      healthCheckPath: '/healthz'
      appSettings: [
        // Key Vault references (resolved at runtime via Managed Identity)
        {
          name: 'COSMOS_CONNECTION_STRING'
          value: '@Microsoft.KeyVault(SecretUri=${cosmosConnectionStringSecretUri})'
        }
        {
          name: 'REDIS_URL'
          value: '@Microsoft.KeyVault(SecretUri=${redisConnectionStringSecretUri})'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: '@Microsoft.KeyVault(SecretUri=${appInsightsConnectionStringSecretUri})'
        }
        // Entra External ID (CIAM) settings
        {
          name: 'AZURE_ENTRA_TENANT_NAME'
          value: 'swapauth'
        }
        {
          name: 'AZURE_ENTRA_TENANT_ID'
          value: '42c78946-657b-4ff6-bc88-5f6fb0c8f5b6'
        }
        {
          name: 'AZURE_ENTRA_AUDIENCE'
          value: 'api://swap-api/access_as_user'
        }
        // App settings
        {
          name: 'COSMOS_DATABASE_NAME'
          value: 'swap-db'
        }
        {
          name: 'REDIS_ENABLED'
          value: 'true'
        }
        {
          name: 'APP_URL'
          value: 'https://stwa-swap-${environment}.azurestaticapps.net'
        }
        {
          name: 'DEBUG'
          value: 'false'
        }
        {
          name: 'WEBSITES_PORT'
          value: '8000'
        }
      ]
    }
  }
  tags: {
    environment: environment
    project: 'swap'
  }
}

// ── Store additional secrets in Key Vault ─────────────────────────────────────
resource kv 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

resource b2cSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: kv
  name: 'AZURE-AD-B2C-CLIENT-SECRET'
  properties: {
    value: b2cClientSecret
  }
}

// ── RBAC: App Service Managed Identity → Key Vault Secrets User ───────────────
var kvSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, appService.id, kvSecretsUserRoleId)
  scope: kv
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', kvSecretsUserRoleId)
    principalId: appService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output appServiceName string = appService.name
output appServiceUrl string = 'https://${appService.properties.defaultHostName}'
output appServicePrincipalId string = appService.identity.principalId
