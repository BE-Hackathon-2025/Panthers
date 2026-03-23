// ── Azure Cache for Redis (Basic C1) ─────────────────────────────────────────
param location string
param environment string
param keyVaultName string

var redisName = 'redis-swap-dev'

resource redisCache 'Microsoft.Cache/redis@2023-08-01' = {
  name: redisName
  location: location
  properties: {
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 1
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    redisConfiguration: {
      'maxmemory-policy': 'allkeys-lru'
    }
  }
  tags: {
    environment: environment
    project: 'swap'
  }
}

// ── Store connection string in Key Vault ──────────────────────────────────────
resource kv 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

var redisConnStr = '${redisCache.properties.hostName}:${redisCache.properties.sslPort},password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'

resource redisSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: kv
  name: 'REDIS-CONNECTION-STRING'
  properties: {
    value: redisConnStr
  }
}

output hostName string = redisCache.properties.hostName
output connectionStringSecretUri string = redisSecret.properties.secretUri
