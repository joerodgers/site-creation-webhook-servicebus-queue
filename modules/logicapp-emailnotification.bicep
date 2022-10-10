param name                  string
param location              string = resourceGroup().location
param connection_office365  string
param connection_servicebus string 
param topic                 string
param subscription          string
param emailAddresses        string
param emailBody             string
param emailSubject          string
param mailboxAddress        string
param productionDate        string

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
        'When_a_message_is_received_in_a_topic_subscription_(auto-complete)': {
          recurrence: {
            frequency: 'Minute'
            interval: 1
          }
          evaluatedRecurrence: {
            frequency: 'Minute'
            interval: 1
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'servicebus\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/@{encodeURIComponent(encodeURIComponent(\'${topic}\'))}/subscriptions/@{encodeURIComponent(\'${subscription}\')}/messages/head'
            queries: {
              subscriptionType: 'Main'
            }
          }
        }
      }
      actions: {
        'Initialize_variable_-_Email_Addresses': {
          runAfter: {
            'Initialize_variable_-_Mailbox_Address': [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'Email Addresses'
                value: emailAddresses
                type: 'string'
              }
            ]
          }
        }
        'Initialize_variable_-_Email_Body': {
          runAfter: {
            'Initialize_variable_-_Email_Subject': [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'Email Body'
                value: emailBody
                type: 'string'
              }
            ]
          }
        }
        'Initialize_variable_-_Email_Subject': {
          runAfter: {
            'Initialize_variable_-_Site_Collection_Creator_Email': [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'Email Subject'
                value: emailSubject
                type: 'string'
              }
            ]
          }
        }
        'Initialize_variable_-_Mailbox_Address': {
          runAfter: {
            'Initialize_variable_-_Email_Body': [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'Mailbox Address'
                value: mailboxAddress
                type: 'string'
              }
            ]
          }
        }
        'Initialize_variable_-_Production_Date': {
          runAfter: {
            'Initialize_variable_-_Email_Addresses': [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'Production Date'
                value: productionDate
                type: 'string'
              }
            ]
          }
        }
        'Initialize_variable_-_Site_Collection_Creator_Email': {
          runAfter: {
            'Initialize_variable_-_Site_Collection_Creator_Name': [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'Site Collection Creator Email'
                type: 'string'
                value: '@body(\'Parse_JSON_-_Parse_Service_Bus_Topic_Message_Content\')?[\'creatorEmail\']'
              }
            ]
          }
        }
        'Initialize_variable_-_Site_Collection_Creator_Name': {
          runAfter: {
            'Initialize_variable_-_Site_Collection_Url': [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'Site Collection Creator Name'
                type: 'string'
                value: '@body(\'Parse_JSON_-_Parse_Service_Bus_Topic_Message_Content\')?[\'creatorName\']'
              }
            ]
          }
        }
        'Initialize_variable_-_Site_Collection_Url': {
          runAfter: {
            'Parse_JSON_-_Parse_Service_Bus_Topic_Message_Content': [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'Site Collection Url'
                type: 'string'
                value: '@body(\'Parse_JSON_-_Parse_Service_Bus_Topic_Message_Content\')?[\'webUrl\']'
              }
            ]
          }
        }
        'Initialize_variable_-_Today_Eastern_Standard_Time': {
          runAfter: {
            'Initialize_variable_-_Production_Date': [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'Today Eastern Standard Time'
                type: 'string'
                value: '@{convertTimeZone(utcNow(),\'UTC\',\'Eastern Standard Time\', \'MM-dd-yyyy\')}'
              }
            ]
          }
        }
        'Parse_JSON_-_Parse_Service_Bus_Topic_Message_Content': {
          runAfter: {
          }
          type: 'ParseJson'
          inputs: {
            content: '@{base64ToString(triggerBody()?[\'ContentData\'])}'
            schema: {
              properties: {
                createdTimeUTC: {
                  type: 'string'
                }
                creatorEmail: {
                  type: 'string'
                }
                creatorName: {
                  type: 'string'
                }
                groupId: {
                  type: 'string'
                }
                webDescription: {
                  type: 'string'
                }
                webTitle: {
                  type: 'string'
                }
                webUrl: {
                  type: 'string'
                }
              }
              type: 'object'
            }
          }
        }
        'Scope_-_Determine_Email_Recipients': {
          actions: {
            'Condition_-_Compare_Today_to_Production_Date': {
              actions: {
                'Set_variable_-_Set_Email_Recipient_to_Site_Collection_Creator_Email_Address': {
                  runAfter: {
                  }
                  type: 'SetVariable'
                  inputs: {
                    name: 'Email Addresses'
                    value: '@variables(\'Site Collection Creator Email\')'
                  }
                }
              }
              runAfter: {
              }
              expression: {
                and: [
                  {
                    greaterOrEquals: [
                      '@ticks(variables(\'Today Eastern Standard Time\'))'
                      '@ticks(variables(\'Production Date\'))'
                    ]
                  }
                ]
              }
              type: 'If'
            }
          }
          runAfter: {
            'Initialize_variable_-_Today_Eastern_Standard_Time': [
              'Succeeded'
            ]
          }
          type: 'Scope'
        }
        'Send_an_email_from_a_shared_mailbox_(V2)': {
          runAfter: {
            'Scope_-_Determine_Email_Recipients': [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            body: {
              Body: '<p>@{variables(\'Email Body\')}</p>'
              Importance: 'Normal'
              MailboxAddress: '@variables(\'Mailbox Address\')'
              Subject: '@variables(\'Email Subject\')'
              To: '@variables(\'Email Addresses\')'
            }
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/v2/SharedMailbox/Mail'
          }
        }
      }
      outputs: {
      }
    }
    parameters: {
      '$connections': {
        value: {
          office365: {
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'office365')
            connectionId: resourceId( 'Microsoft.Web/connections', connection_office365 )
            connectionName: connection_office365
          }
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

output objectId string = logic.identity.principalId
