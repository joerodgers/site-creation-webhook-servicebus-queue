param name       string
param servicebus string
param location   string = resourceGroup().location

#disable-next-line BCP081
resource connection 'Microsoft.Web/connections@2018-07-01-preview' = {
  name: name
  location: location
  properties: {
    displayName: name
    api: {
        id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'servicebus')
    }
    parameterValueSet: {
      name: 'managedIdentityAuth'
      values: {
        namespaceEndpoint: {
          value: 'sb://${servicebus}.servicebus.windows.net/'
        }
      }
    }
  }
}

output name string = connection.name
output id string   = connection.id
