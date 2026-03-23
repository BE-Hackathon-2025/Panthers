// ============================================================
// $wap — Azure Infrastructure (main orchestrator)
// Subscription: Azure Subscription 1  |  Resource Group: otito
// Deploy: az deployment group create --resource-group otito --template-file infra/main.bicep
// ============================================================

targetScope = 'resourceGroup'

@description('Azure region for all resources')
param location string = 'centralus'

@description('Environment tag (dev / staging / prod)')
param environment string = 'dev'

@description('Azure AD B2C client secret for the backend app registration')
@secure()
param b2cClientSecret string

// ── Module: Key Vault (provision first — others write secrets into it) ──────
module kv 'modules/keyvault.bicep' = {
  name: 'kv-swap-prod'
  params: {
    location: location
    environment: environment
  }
}

// ── Module: Monitoring (Log Analytics + Application Insights) ────────────────
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring-swap-prod'
  params: {
    location: location
    environment: environment
    keyVaultName: kv.outputs.keyVaultName
  }
  dependsOn: [kv]
}

// ── Module: Cosmos DB ────────────────────────────────────────────────────────
module cosmos 'modules/cosmos.bicep' = {
  name: 'cosmos-swap-prod'
  params: {
    location: location
    environment: environment
    keyVaultName: kv.outputs.keyVaultName
  }
  dependsOn: [kv]
}

// ── Module: Redis Cache ───────────────────────────────────────────────────────
module redis 'modules/redis.bicep' = {
  name: 'redis-swap-prod'
  params: {
    location: location
    environment: environment
    keyVaultName: kv.outputs.keyVaultName
  }
  dependsOn: [kv]
}

// ── Module: App Service (backend) ────────────────────────────────────────────
module appservice 'modules/appservice.bicep' = {
  name: 'appservice-swap-prod'
  params: {
    location: location
    environment: environment
    keyVaultName: kv.outputs.keyVaultName
    appInsightsConnectionStringSecretUri: monitoring.outputs.appInsightsConnectionStringSecretUri
    cosmosConnectionStringSecretUri: cosmos.outputs.connectionStringSecretUri
    redisConnectionStringSecretUri: redis.outputs.connectionStringSecretUri
    b2cClientSecret: b2cClientSecret
  }
  dependsOn: [kv, monitoring, cosmos, redis]
}

// ── Module: Static Web App (frontend) ────────────────────────────────────────
module staticwebapp 'modules/staticwebapp.bicep' = {
  name: 'stwa-swap-frontend'
  params: {
    location: location
    environment: environment
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────
output keyVaultName string = kv.outputs.keyVaultName
output appServiceUrl string = appservice.outputs.appServiceUrl
output staticWebAppUrl string = staticwebapp.outputs.staticWebAppUrl
output staticWebAppDeploymentToken string = staticwebapp.outputs.deploymentToken
output cosmosAccountName string = cosmos.outputs.accountName
