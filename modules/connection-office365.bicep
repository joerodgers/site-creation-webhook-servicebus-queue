param name           string
param location       string = resourceGroup().location

resource connection 'Microsoft.Web/connections@2016-06-01' = {
  name: name
  location: location
  properties: {
    displayName: name
    api: {
      name: name
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'office365')
    }
  }
}

output name string = connection.name
output id   string = connection.id
