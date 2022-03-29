// PARAMETERS
@description('Deployment location.  Default location will be the location of the resource group.')
param location string = toLower(resourceGroup().location)

// VARIABLES
var suffix = toLower(uniqueString(resourceGroup().id))

// RESOURCES
resource service_bus_namespace 'Microsoft.ServiceBus/namespaces@2021-11-01' = {
  name: toLower('servicebus-${suffix}')
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    disableLocalAuth: false
    zoneRedundant: false
  }
}

resource service_bus_namespace_authorization_rule 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2021-06-01-preview' = {
  name: 'send-message-authorization-rule'
  parent: service_bus_namespace
  properties: {
    rights: [
      'Send'
    ]
  }
}

resource service_bus_topic 'Microsoft.ServiceBus/namespaces/topics@2021-11-01' = {
  name: 'spo-site-creation'
  parent: service_bus_namespace
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

resource service_bus_subscription_all_sites 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2021-11-01' = {
  name: 'All-site-template'
  parent: service_bus_topic
}

resource service_bus_subscription_teamchannel 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2021-11-01' = {
  name: 'Channel-site-template'
  parent: service_bus_topic

  resource service_bus_subscription_rule_teamchannel 'rules@2021-11-01' = {
    name: 'TEAMCHANNEL'
    properties: {
      filterType: 'CorrelationFilter'
      correlationFilter: {
        label: 'TEAMCHANNEL'
      }
    }
  }
}

resource service_bus_subscription_sitepagepublishing 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2021-11-01' = {
  name: 'Communication-site-template'
  parent: service_bus_topic

  resource service_bus_subscription_rule_sitepagepublishing 'rules@2021-11-01' = {
    name: 'TEMPLATE-FILTER'
    properties: {
      filterType: 'CorrelationFilter'
      correlationFilter: {
        label: 'SITEPAGEPUBLISHING'
      }
    }
  }
}

resource service_bus_subscription_group 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2021-11-01' = {
  name: 'Team-site-template'
  parent: service_bus_topic

  resource service_bus_subscription_rule_group 'rules@2021-11-01' = {
    name: 'GROUP'
    properties: {
      filterType: 'CorrelationFilter'
      correlationFilter: {
        label: 'GROUP'
      }
    }
  }
}

resource service_bus_subscription_sts 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2021-11-01' = {
  name: 'Team-site-template-no-group'
  parent: service_bus_topic

  resource service_bus_subscription_rule_sts 'rules@2021-11-01' = {
    name: 'TEMPLATE-FILTER'
    properties: {
      filterType: 'CorrelationFilter'
      correlationFilter: {
        label: 'STS'
      }
    }
  }
}

resource service_bus_subscription_disable_sharing_non_owners 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2021-11-01' = {
  name: 'disable-sharing-for-non-owners'
  parent: service_bus_topic

  resource service_bus_subscription_rule_sts 'rules@2021-11-01' = {
    name: 'TEMPLATE-FILTER'
    properties: {
      filterType: 'SqlFilter'
      sqlFilter: {
        sqlExpression: 'sys.label in ( \'GROUP\', \'STS\', \'SITEPAGEPUBLISHING\' )'
        compatibilityLevel: 20
      }
    }
  }
}

resource logic_app 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'logic-${suffix}'
  location: location
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        'http_request': {
          type: 'request'
          kind: 'http'
          inputs: {
            schema: {
              type: 'object'
              properties: {
                createdTimeUTC: {
                  type: 'string'
                }
                creatorEmail: {
                  type: 'string'
                }
                groupId: {
                  type: 'string'
                }
                parameters: {
                  type: 'object'
                  properties: {
                    template: {
                      type: 'string'
                      minLength: 3
                    }
                  }
                  required: [
                    'template'
                  ]
                }
                webDescription: {
                  type: 'string'
                }
                webTitle: {
                  type: 'string'
                }
                webUrl: {
                  type: 'string'
                  minLength: 25
                }
              }
              required: [
                'webUrl'
              ]
            }
          }
        }
      }
      actions: {
        Input_validation: {
          actions: {
            'Send_message': {
              type: 'ApiConnection'
              description: 'Submit message details to Azure Service Bus Topic'
              inputs: {
                body: {
                  ContentType: 'application/json'
                  ContentData: '@{base64(concat(\'{   "webUrl" : "\', triggerBody()?[\'webUrl\'], \'", "webTitle" : "\', triggerBody()?[\'webTitle\'], \'", "webDescription" : "\', triggerBody()?[\'webDescription\'], \'", "creatorName" : "\', triggerBody()?[\'creatorName\'], \'", "creatorEmail" : "\', triggerBody()?[\'creatorEmail\'], \'", "createdTimeUTC" : "\', triggerBody()?[\'createdTimeUTC\'], \'", "groupId" : "\', triggerBody()?[\'groupId\'], \'", }\'))}'
                  Label: '@{toUpper(triggerBody()?[\'parameters\']?[\'template\'])}'
                }
                host: {
                  connection: {
                    Name: '@parameters(\'$connections\')[\'servicebus\'][\'connectionId\']'
                  }
                }
                method: 'post'
                path: '/@{encodeURIComponent(encodeURIComponent(\'${service_bus_topic.name}\'))}/messages'
                queries: {
                  systemProperties: 'None'
                }
              }
            }
          }
          description: 'Returns TRUE if Template and WebUrl are not empty strings'
          else: {
            actions: {
              Terminate: {
                description: 'Either Template or WebUrl was empty'
                inputs: {
                  runError: {
                    message: 'Failed due to invalide Template or WebUrl input value.'
                  }
                  runStatus: 'Failed'
                }
                runAfter: {}
                type: 'Terminate'
              }
            }
          }
          expression: {
            and: [
              {
                not: {
                  equals: [
                    '@empty(coalesce(triggerBody()[\'webUrl\'],\'\'))'
                    '@true'
                  ]
                }
              }
              {
                not: {
                  equals: [
                    '@empty(coalesce(triggerBody()?[\'parameters\'],\'\'))'
                    '@true'
                  ]
                }
              }
              {
                not: {
                  equals: [
                    '@empty(coalesce(triggerBody()?[\'parameters\']?[\'template\'],\'\'))'
                    '@true'
                  ]
                }
              }
            ]
          }
          runAfter: {}
          type: 'If'
        }
      }
    }
    parameters: {
      '$connections': {
        value: {
          servicebus: {
            id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/servicebus'
            connectionId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/connections/${logic_app_api_connection.name}'
            connectionName: '${logic_app_api_connection.name}'
          }
        }
      }
    }
  }
}

resource logic_app_api_connection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'apiconnection-servicebus-${suffix}'
  dependsOn: [
    service_bus_namespace
  ]
  location: location
  properties: {
    displayName: 'apiconnection-${suffix}'
    statuses: [
      {
        status: 'Connected'
      }
    ]
    parameterValues: {
      connectionString: listKeys(service_bus_namespace_authorization_rule.id, service_bus_namespace_authorization_rule.apiVersion).primaryConnectionString
    }
    api: {
      id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/servicebus'
      name: 'apiconnection-${suffix}'
      displayName: 'Service Bus'
      description: 'Connect to Azure Service Bus to send and receive messages. You can perform actions such as send to queue, send to topic, receive from queue, receive from subscription, etc.'
      iconUri: 'https://connectoricons-prod.azureedge.net/releases/v1.0.1546/1.0.1546.2665/servicebus/icon.png'
      brandColor: '#c4d5ff'
      type: 'Microsoft.Web/locations/managedApis'
    }
  }
}
