'use strict'

TaskFactory = ($resource) ->
  $resource('/api/v1/tasks/:id.json', { id: '@id' },
    query:
      url: '/api/v1/tasks.json'
      isArray: true

    update:
      method: 'PUT'
  )

angular
  .module('Sapling')
  .factory('TaskResource', ['$resource', TaskFactory])
