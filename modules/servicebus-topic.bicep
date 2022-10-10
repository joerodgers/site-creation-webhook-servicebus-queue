param name string
param parent string

resource servicebus 'Microsoft.ServiceBus/namespaces@2021-11-01' existing = {
  name: parent
}

resource topic 'Microsoft.ServiceBus/namespaces/topics@2021-11-01' = {
  name: name
  parent: servicebus
  properties: {
    defaultMessageTimeToLive: 'P14D'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    enableBatchedOperations: true
    status: 'Active'
    supportOrdering: true
    autoDeleteOnIdle: 'P10675199DT2H48M5.4775807S'
    enablePartitioning: false
    enableExpress: false
  }
}

output name string = topic.name
