@description('The name of the function app that you wish to create.')
param appName string = 'fnapp${uniqueString(resourceGroup().id)}'

@description('Storage Account type')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param storageAccountType string = 'Standard_LRS'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('The language worker runtime to load in the function app.')
@allowed([
  'python'
])
param runtime string = 'python'

@description('List of log categories that needs to enabled.')
param logs array = [
  {
    category: 'FunctionAppLogs'
    enabled: true
  }
]

@description('List of metrics to enable')
param metrics array = [
  {
    enabled: true
    category: 'AllMetrics'
  }
]

@description('The API Key for the Weather API')
param weatherApiKey string

@description('The name for the API key in KeyVault')
param weatherApiKeySecretName string

var functionAppName = appName
var hostingPlanName = appName
var applicationInsightsName = appName
var storageAccountName = '${uniqueString(resourceGroup().id)}azfunctions'
var functionWorkerRuntime = runtime
var logAnalyticsWorkspaceName = '${functionAppName}-logAnalytics'
var functionAppDiagnosticLoggingSetting = '${functionAppName}-logAnalytics-setting'
var keyVaultName = 'kv-${functionAppName}'
var logQueryAlertName = 'logq-${functionAppName}'

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  properties: {
    enabledForTemplateDeployment: true
    tenantId: subscription().tenantId
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enableRbacAuthorization: true
    accessPolicies: []
    sku: {
      name: 'standard'
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'Storage'
  properties: {
    supportsHttpsTrafficOnly: true
    defaultToOAuthAuthentication: true
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  kind: 'app,linux'
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      linuxFxVersion: 'python|3.9'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~14'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
        {
          name: 'WEATHER_API_KEY_NAME'
          value: weatherApiKeySecretName
        }
        {
          name: 'WEATHER_API_KEY_TEMP'
          value: weatherApiKey
        }
        {
          name: 'KEY_VAULT_URL'
          value: keyVault.properties.vaultUri
        }
        {
          name: 'AZURE_CLIENT_ID'
          value: ''
        }
      ]
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
}

var appServiceKeyVaultRoleDefinitionResourceId = '/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6'

resource appServiceAccessToKeyVault 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, functionApp.id, appServiceKeyVaultRoleDefinitionResourceId)
  properties: {
    roleDefinitionId: appServiceKeyVaultRoleDefinitionResourceId
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
  }
}

resource functionAppDiagnosticLogSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: functionAppDiagnosticLoggingSetting
  scope: functionApp
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: logs
    metrics: metrics
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

resource logQueryWeatherLatencyAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: logQueryAlertName
  location: location
  properties: {
    description: 'The Weather API latency exceeds acceptable thresholds'
    severity: 2
    enabled: true
    actions: {
      actionGroups: []
    }
    scopes: [
      logAnalyticsWorkspace.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: 'FunctionAppLogs | where Category == \'Host.Function.Console\' | extend msg=replace(@"\'", @\'"\', Message) | extend msg_json=parse_json(msg) | extend timestamp=todatetime(msg_json.timestamp), invocation_id=tostring(msg_json._Context__invocation_id), event=msg_json.event, scope=msg_json.scope, function=msg_json.function | sort by timestamp asc | project timestamp, invocation_id, event, scope, function | where event in ("Exiting", "Entering") and function == \'city_request_to_weather\' | extend diff = case(event == "Exiting", datetime_diff(\'millisecond\', timestamp, prev(timestamp)), 0) | summarize latency = max(diff) by invocation_id | summarize avg_latency = avg(latency)'
          metricMeasureColumn: 'avg_latency'
          operator: 'GreaterThan'
          timeAggregation: 'Average'
          threshold: 500
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: true
  }
}
