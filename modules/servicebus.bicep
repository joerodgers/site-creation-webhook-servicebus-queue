param name     string
param location string = resourceGroup().location

#disable-next-line BCP081
resource servicebus 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' = {
  name: name
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    minimumTlsVersion: '1.2'
    disableLocalAuth: true
  }
}

output endpoint string = replace(replace(servicebus.properties.serviceBusEndpoint, 'https://', 'sb://'), ':443/', '')
output name     string = servicebus.name
