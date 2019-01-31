'use strict'

UserResourceFactory = ($resource) ->
  $resource('/api/v1/users/:id.json', { id: '@id' },
    update:
      method: 'PUT'
    get:
      method: 'GET'
    limited_users:
      method: 'GET'
      isArray: true
    task_users:
      url: '/api/v1/users/task_users.json'
      method: 'GET'
      isArray: true
    home_user:
      method: 'GET'
    roadmap_user:
      url: '/api/v1/users/:id/roadmap_user.json'
      method: 'GET'
    user_activity_stream:
      url: '/api/v1/users/:user_id/user_activity_stream.json'
      method: 'GET'
      params:{
        user_id: '@user_id'
      }
    hide_activity:
      url: '/api/v1/users/:user_id/hide_activity.json'
      method: 'PUT'
      params:{
        user_id: '@user_id',
        activity_id: '@activity_id',
        activity_type: '@activity_type'
      }
  )

angular
  .module('Sapling')
  .factory('UserResource', ['$resource', UserResourceFactory])
