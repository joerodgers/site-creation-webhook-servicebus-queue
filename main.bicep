param location       string = resourceGroup().location
param mailboxAddress string
param emailBody      string
param emailSubject   string
param emailAddresses string
param productionDate string

// unique suffix
var suffix = toLower(uniqueString(resourceGroup().id))

module servicebus 'modules/servicebus.bicep' = {
  name: 'servicebus'
  params: {
    name: 'sb-messages-${suffix}'
    location: location
  }
}

module topic 'modules/servicebus-topic.bicep' = {
  name: 'servicebus-topic_spo-site-creation'
  params: {
    name: 'spo-site-creation'
    parent: servicebus.outputs.name
  }
}

module subscription 'modules/servicebus-topic-subscription.bicep' = {
  name: 'subscription_all-site-templates'
  params: {
    name: 'new-site-email-notice'
    servicebus: servicebus.outputs.name
    topic: topic.outputs.name
  }
}

module connection_servicebus 'modules/connection-servicebus.bicep' = {
  name: 'connection-servicebus'
  params: {
    name: 'connection-servicebus-${suffix}'
    location: location
    servicebus: servicebus.outputs.name
  }
}

module connection_office365 'modules/connection-office365.bicep' = {
  name: 'connection-office365'
  params: {
    name: 'connection-office365-${suffix}'
    location: location
  }
}

module logic_webhook 'modules/logicapp-webhook.bicep' = {
  name: 'logic-webhook'
  params: {
    name: 'logic-webhook-${suffix}'
    location: location
    topic: topic.outputs.name
    connection_servicebus: connection_servicebus.outputs.name
  }
}

module logic_emailnotification 'modules/logicapp-emailnotification.bicep' = {
  name: 'logic-emailnotification'
  params: {
    name: 'logic-emailnotification-${suffix}'
    location: location
    connection_servicebus: connection_servicebus.outputs.name
    connection_office365: connection_office365.outputs.name
    emailAddresses: emailAddresses
    emailBody: emailBody
    emailSubject: emailSubject
    mailboxAddress: mailboxAddress
    productionDate: productionDate
    subscription: subscription.outputs.name
    topic: topic.outputs.name
  }
}

module roleassignments 'modules/roleAssignments.bicep' = {
  name: 'roleassignments'
  params: {
    roleAssignments: [
      {
        principalId: logic_emailnotification.outputs.objectId
        roleDefinitionId: '090c5cfd-751d-490a-894a-3ce6f1109419' // Azure Service Bus Data Owner - https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
        principalType: 'ServicePrincipal'
      }
      {
        principalId: logic_webhook.outputs.objectId
        roleDefinitionId: '090c5cfd-751d-490a-894a-3ce6f1109419' // Azure Service Bus Data Owner - https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
        principalType: 'ServicePrincipal'
      }
    ]
  }
}

#disable-next-line outputs-should-not-contain-secrets
output webhookUrl string = logic_webhook.outputs.webhookUrl
output servicebus string = servicebus.outputs.endpoint
