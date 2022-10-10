param name                  string
param location              string = resourceGroup().location
param connection_servicebus string
param topic                 string

resource logic 'Microsoft.Logic/workflows@2019-05-01' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {
          }
          type: 'Object'
        }
      }
      triggers: {
        http_request: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
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
                  properties: {
                    template: {
                      minLength: 3
                      type: 'string'
                    }
                  }
                  required: [
                    'template'
                  ]
                  type: 'object'
                }
                webDescription: {
                  type: 'string'
                }
                webTitle: {
                  type: 'string'
                }
                webUrl: {
                  minLength: 25
                  type: 'string'
                }
              }
              required: [
                'webUrl'
              ]
              type: 'object'
            }
          }
        }
      }
      actions: {
        Input_validation: {
          actions: {
            Send_message: {
              runAfter: {
              }
              type: 'ApiConnection'
              inputs: {
                body: {
                  ContentData: '@{base64(concat(\'{   "webUrl" : "\', triggerBody()?[\'webUrl\'], \'", "webTitle" : "\', triggerBody()?[\'webTitle\'], \'", "webDescription" : "\', triggerBody()?[\'webDescription\'], \'", "creatorName" : "\', triggerBody()?[\'creatorName\'], \'", "creatorEmail" : "\', triggerBody()?[\'creatorEmail\'], \'", "createdTimeUTC" : "\', triggerBody()?[\'createdTimeUTC\'], \'", "groupId" : "\', triggerBody()?[\'groupId\'], \'", }\'))}'
                  ContentType: 'application/json'
                  Label: '@{toUpper(triggerBody()?[\'parameters\']?[\'template\'])}'
                }
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'servicebus\'][\'connectionId\']'
                  }
                }
                method: 'post'
                path: '/@{encodeURIComponent(encodeURIComponent(\'${topic}\'))}/messages'
                queries: {
                  systemProperties: 'None'
                }
              }
              description: 'Submit message details to Azure Service Bus Topic'
            }
          }
          runAfter: {
          }
          else: {
            actions: {
              Terminate: {
                runAfter: {
                }
                type: 'Terminate'
                inputs: {
                  runError: {
                    message: 'Failed due to invalide Template or WebUrl input value.'
                  }
                  runStatus: 'Failed'
                }
                description: 'Either Template or WebUrl was empty'
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
          type: 'If'
          description: 'Returns TRUE if Template and WebUrl are not empty strings'
        }
      }
    }
    parameters: {
      '$connections': {
        value: {
          servicebus: {
            connectionId: resourceId( 'Microsoft.Web/connections', connection_servicebus )
            connectionName: connection_servicebus
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
              }
            }
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'servicebus')
          }
        }
      }
    }
  }
}

#disable-next-line outputs-should-not-contain-secrets
output webhookUrl string = listCallbackURL('${logic.id}/triggers/http_request', '2017-07-01').value
output objectId   string = logic.identity.principalId
output id         string = logic.id

