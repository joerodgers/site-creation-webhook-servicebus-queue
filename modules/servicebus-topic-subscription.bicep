param name       string
param servicebus string
param topic      string

resource sb 'Microsoft.ServiceBus/namespaces@2021-11-01' existing = {
  name: servicebus
}

resource tp 'Microsoft.ServiceBus/namespaces/topics@2021-11-01' existing = {
  name: topic
  parent: sb
}

resource subscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2021-11-01' = {
  name: name
  parent: tp
}

output name string = subscription.name
