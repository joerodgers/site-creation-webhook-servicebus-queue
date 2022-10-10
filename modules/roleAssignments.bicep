param roleAssignments array 

resource ra 'Microsoft.Authorization/roleAssignments@2020-04-01-preview'  = [for (roleAssignment, index) in roleAssignments: {
  name:  guid(roleAssignment.principalId, roleAssignment.roleDefinitionId, resourceGroup().id)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleAssignment.roleDefinitionId)
    principalId: roleAssignment.principalId
    principalType: roleAssignment.principalType
  }
}]

