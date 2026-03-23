// ── Cosmos DB (NoSQL API, Serverless) ─────────────────────────────────────────
param location string
param environment string
param keyVaultName string

var cosmosName = 'cosmos-swap-dev'
var databaseName = 'swap-db'

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: cosmosName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    backupPolicy: {
      type: 'Continuous'
      continuousModeProperties: {
        tier: 'Continuous7Days'
      }
    }
  }
  tags: {
    environment: environment
    project: 'swap'
  }
}

// ── Database ──────────────────────────────────────────────────────────────────
resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = {
  parent: cosmosAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
}

// ── Containers ────────────────────────────────────────────────────────────────
var containers = [
  { name: 'profiles',       partitionKey: '/uid' }
  { name: 'conversations',  partitionKey: '/conversation_id' }
  { name: 'messages',       partitionKey: '/conversation_id' }
  { name: 'swap_requests',  partitionKey: '/uid' }
  { name: 'blocks',         partitionKey: '/uid' }
  { name: 'reports',        partitionKey: '/uid' }
]

resource cosmosContainers 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-04-15' = [for c in containers: {
  parent: database
  name: c.name
  properties: {
    resource: {
      id: c.name
      partitionKey: {
        paths: [c.partitionKey]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
      }
    }
  }
}]

// ── Store connection string in Key Vault ──────────────────────────────────────
resource kv 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

resource cosmosSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: kv
  name: 'COSMOS-CONNECTION-STRING'
  properties: {
    value: cosmosAccount.listConnectionStrings().connectionStrings[0].connectionString
  }
}

output accountName string = cosmosAccount.name
output connectionStringSecretUri string = cosmosSecret.properties.secretUri
