'use strict'

class TasksController
  constructor:($rootScope, Template, TaskUserConnectionResource, TaskResource, Notification,
              AdminWorkstreamResource, AdminTaskResource, AdminUserResource, AdminTaskUserConnectionResource,
              Upload, $filter, $q, $environment, WorkstreamResource, $timeout, TaskUserConnectionPaginatedResource,
              UserResource, $state, $uibModal) ->
    vm = @
    vm.current_user = $rootScope.user
    vm.display_deadline = false
    vm.select_workstream = false
    vm.is_permitted = (vm.current_user.role == 'admin' || vm.current_user.role == 'account_owner' || vm.current_user.id == vm.employee.manager_id)
    vm.dateFormat = $rootScope.dateFormat
    vm.filter_options = [
      {label: "all", text: I18n.t('board.tasks.all')},
      {label: "incomplete", text: I18n.t('board.tasks.incomplete')},
      {label: "employee", text: I18n.t('board.tasks.by_employee')},
      {label: "due_date", text: I18n.t('board.tasks.by_due_date')},
      {label: "completed", text: I18n.t('board.tasks.completed')}
    ]
    vm.filter_button_text = I18n.t('board.tasks.view') + vm.filter_options[1].text
    vm.display_task = vm.filter_options[1].label
    vm.workstream_loading = false
    vm.callee = 'task_ctrl'
    vm.current_ws = null

    vm.getDatepickerOptions = (selector)->
      return $rootScope.getDatepickerOptions(selector)

    loadEmployees = ->
      if vm.current_user.id == vm.employee.id || !vm.employee.is_onboarding
          UserResource
            .task_users(owner_id: vm.employee.id)
            .$promise
            .then (response)->
              vm.workstreams = response
              openWorkstream(0) if vm.workstreams.length == 1
              filterWorkstreams(vm.display_task)
              vm.workstream_loading = false
        else
          UserResource
            .task_users(user_id: vm.employee.id)
            .$promise
            .then (response)->
              vm.workstreams = response
              openWorkstream(0) if vm.workstreams.length == 1
              filterWorkstreams(vm.display_task)
              vm.workstream_loading = false

    loadWorkstreams = ->
      if vm.current_user.id == vm.employee.id || !vm.employee.is_onboarding
          WorkstreamResource
            .query(owner_id: vm.employee.id)
            .$promise
            .then (response) ->
              vm.workstreams = response
              if vm.display_task == "incomplete"
                incomplete_workstream = vm.getIncompleteWorkstream()
                openWorkstream(incomplete_workstream) if incomplete_workstream != -1
              else if vm.display_task == "completed"
                complete_workstream = vm.getCompleteWorkstream()
                openWorkstream(complete_workstream) if complete_workstream != -1
              else
                openWorkstream(0) if vm.workstreams.length == 1
              filterWorkstreams(vm.display_task)
              vm.workstream_loading = false
        else
          WorkstreamResource
            .query(user_id: vm.employee.id)
            .$promise
            .then (response) ->
              vm.workstreams = response
              if vm.display_task == "incomplete"
                incomplete_workstream = vm.getIncompleteWorkstream()
                openWorkstream(incomplete_workstream) if incomplete_workstream != -1
              else if vm.display_task == "completed"
                complete_workstream = vm.getCompleteWorkstream()
                openWorkstream(complete_workstream) if complete_workstream != -1
              else
                openWorkstream(0) if vm.workstreams.length == 1
              filterWorkstreams(vm.display_task)
              vm.workstream_loading = false

    formatDueDates = (due_dates) ->
      now = moment()
      due_dates.forEach((date) ->

        due_date = moment(date.name)
        if now.isBefore(due_date)

          ago = due_date.diff(now, 'days')
          if ago == 0
            date.name = I18n.t('board.tasks.tomorrow')
          else
            date.name = moment(due_date).format('MMMM D YYYY')

        else
          ago = now.diff(due_date, 'days')
          if ago == 1
            date.name =  I18n.t('board.tasks.yesterday')
          else if ago == 0
            date.name =  I18n.t('board.tasks.today')
          else
            date.name =  moment(due_date).format('MMMM D YYYY')

      ) if due_dates

      due_dates

    loadDueDates = ->
      if vm.current_user.id == vm.employee.id || !vm.employee.is_onboarding
          TaskUserConnectionResource
            .task_due_dates(owner_id: vm.employee.id)
            .$promise
            .then (response) ->
              vm.workstreams = formatDueDates(response)
              openWorkstream(0) if vm.workstreams.length == 1
              filterWorkstreams(vm.display_task)
              vm.workstream_loading = false
        else
          TaskUserConnectionResource
            .task_due_dates(user_id: vm.employee.id)
            .$promise
            .then (response) ->
              vm.workstreams = formatDueDates(response)
              openWorkstream(0) if vm.workstreams.length == 1
              filterWorkstreams(vm.display_task)
              vm.workstream_loading = false

    loadNextPage = (workstream, params) ->
      TaskUserConnectionPaginatedResource
        .query(params)
        .$promise
        .then (response) ->
          response.task_user_connections.forEach((connection) ->
            workstream.tasks.push connection
          ) if response.task_user_connections

          filterTasks(workstream, vm.display_task)
          if workstream.tasks.length < workstream.total_tasks
            params.page += 1
            loadNextPage(workstream, params)
          else
            workstream._tasks_loading = false

    vm.loadTasks = (workstream, reload) ->
      params = {
        per_page: 25
        page: 1
      }
      if !workstream.tasks || reload
        workstream._tasks_loading = true

        if vm.current_user.id == vm.employee.id || !vm.employee.is_onboarding
          params.owner_id = vm.employee.id
          params.is_owner_view = true
          if vm.display_task == "employee"
            params.user_id = workstream.id
          else if vm.display_task == "due_date"
            params.due_date = workstream.due_date
          else
            params.workstream_id = workstream.id

          workstream.tasks ?= []
          loadNextPage(workstream, params)

        else
          params.user_id = vm.employee.id
          params.is_owner_view = false
          if vm.display_task == "employee"
            params.owner_id = workstream.id
          else if vm.display_task == "due_date"
            params.due_date = workstream.due_date
          else
            params.workstream_id = workstream.id
          params.exclude_users_state = true
          workstream.tasks ?= []
          loadNextPage(workstream, params)

    openWorkstream = (index)->
      vm.workstreams[index].is_open = true
      vm.loadTasks(vm.workstreams[index])

    getOutstandingTaskCount = (workstream) ->
      return workstream.outstanding_tasks_count if !workstream.tasks

      workstream.tasks.reduce (sum, task)->
        sum + (if task.state == 'in_progress' then 1 else 0)
      , 0

    openActiveWorkstream = ->
      index = vm.workstreams.indexOf($filter('filter')(vm.workstreams, {id: vm.activeWorkstreamId}, true)[0])
      openWorkstream(index) if index > -1

    vm.getIncompleteWorkstream = ->
      workstream_index = -1
      sum = 0
      vm.workstreams.forEach (workstream, index) ->
        if getOutstandingTaskCount(workstream) > 0
          sum += 1
          workstream_index = index

      if sum == 1 then workstream_index else -1

    incomplete_workstream = vm.getIncompleteWorkstream()

    if incomplete_workstream != -1
      openWorkstream(incomplete_workstream)
    else if vm.activeWorkstreamId
      openActiveWorkstream()

    getOverdueTaskCount = (workstream) ->
      return workstream.overdue_tasks_count  if !workstream.tasks

      workstream.tasks.reduce (sum, task)->
        sum + (if vm.isTaskOverdue(task) then 1 else 0)
      , 0

    getCompletedTaskCount = (workstream) ->
      return workstream.completed_tasks_count if !workstream.tasks

      workstream.tasks.reduce (sum, task)->
        sum + (if task.state == 'completed' then 1 else 0)
      , 0

    vm.getCompleteWorkstream = ->
      workstream_index = -1
      sum = 0
      vm.workstreams.forEach (workstream, index) ->
        if getCompletedTaskCount(workstream) > 0
          sum += 1
          workstream_index = index

      if sum == 1 then workstream_index else -1

    complete_workstream = vm.getCompleteWorkstream()

    if vm.dispay_task == 'completed' && complete_workstream != -1
      openWorkstream(complete_workstream)
    else if vm.activeWorkstreamId
      openActiveWorkstream()

    updateWorkstream = (workstream) ->
      workstream.outstanding_tasks_count = getOutstandingTaskCount(workstream)
      workstream.completed_tasks_count = getCompletedTaskCount(workstream)
      workstream.overdue_tasks_count = getOverdueTaskCount(workstream)
      workstream.total_tasks = workstream.tasks.length if !workstream.tasks

    updateUser = () ->
      if $rootScope.user.id == vm.employee.id
        AdminUserResource
          .get({id: vm.employee.id})
          .$promise
          .then (response) ->
            vm.employee = $rootScope.user = response

    vm.visibleWorkstreamCount = ->
      vm.workstreams.reduce (sum, workstream) ->
        sum + if workstream.show_workstream then 1 else 0
      , 0

    vm.deleteWorkstream = (workstream) ->
      params = {filter: vm.display_task}
      if vm.current_user.id == vm.employee.id || (vm.current_user.role == 'account_owner' && !vm.employee.is_onboarding)
        params.owner_id = vm.employee.id

        if vm.display_task == "employee"
          params.user_id = workstream.id
        else if vm.display_task == "due_date"
          params.due_date = workstream.due_date
          params.user_id = vm.employee.id
        else
          params.workstream_id = workstream.id
          params.user_id = vm.employee.id

      else
        params.user_id = vm.employee.id

        if vm.display_task == "employee"
          params.owner_id = workstream.id
        else if vm.display_task == "due_date"
          params.due_date = workstream.due_date
        else
          params.workstream_id = workstream.id

      AdminTaskUserConnectionResource
        .destroy_by_filter(params)
        .$promise
        .then ->
          Notification.success(
            title: I18n.t('notifications.success')
            message: I18n.t('notifications.admin.workstreams.removed')
          )
          index = vm.workstreams.indexOf(workstream)
          vm.workstreams.splice(index, 1) if index > -1

          updateUser()
          vm.updateOverdueTasks()
          vm.updateTasksCount()

    vm.isTaskOverdue = (task)->
      task.state == 'in_progress' && moment().isAfter(task.due_date)

    vm.tasksOutstandingCount = ()->
      return 0 if !vm.workstreams

      vm.workstreams.reduce (sum, workstream)->
        sum + workstream.outstanding_tasks_count
      , 0

    vm.tasksOverdueCount = ()->
      return 0 if !vm.workstreams

      vm.workstreams.reduce (sum, workstream)->
        sum + workstream.overdue_tasks_count
      , 0

    vm.displayDeadline = (task) ->
      now = moment()
      due_date = moment(task.due_date)

      if now.isBefore(due_date)

        ago = due_date.diff(now, 'days')
        if ago == 0
          I18n.t('board.tasks.tomorrow')
        else
          moment(due_date).format('MMM D')

      else

        ago = now.diff(due_date, 'days')
        if ago == 1
          I18n.t('board.tasks.yesterday')
        else if ago == 0
          I18n.t('board.tasks.today')
        else
          I18n.t('board.tasks.days_ago', days: ago)

    vm.updateOverdueTasks = ->
      if vm.current_user.id == vm.employee.id
        vm.current_user.overdue_tasks = vm.tasksOverdueCount()

    vm.updateTasksCount = ->
      if vm.current_user.id == vm.employee.id || !vm.employee.is_onboarding
        vm.employee.outstanding_owner_tasks_count = vm.tasksOutstandingCount()
      else
        vm.employee.outstanding_tasks_count = vm.tasksOutstandingCount()

    vm.filterTaskBy = (filter, index) ->
      vm.filter_button_text = I18n.t('board.tasks.view') + vm.filter_options[index].text
      if filter == "employee" && vm.display_task != "employee"
        vm.workstream_loading = true
        loadEmployees()
      else if filter == "due_date" && vm.display_task != "due_date"
        vm.workstream_loading = true
        loadDueDates()
      else if filter == "all" && vm.display_task != "all"
        vm.workstream_loading = true
        loadWorkstreams()
      else if filter == "incomplete" && vm.display_task != "incomplete"
        vm.workstreams[incomplete_workstream].is_open = true if incomplete_workstream != -1
        vm.workstream_loading = true
        loadWorkstreams()
      else if filter == "completed" && vm.display_task != "completed_tasks_count"
        vm.workstreams[complete_workstream].is_open = true if complete_workstream != -1
        vm.workstream_loading = true
        loadWorkstreams()

      vm.display_task = filter

    completedVisibleTasks = (workstream, state) ->
      return 0 if !workstream.tasks && state == 'in_progress'
      return workstream.completed_tasks_count if !workstream.tasks && state == 'completed'

      workstream.tasks.reduce (sum, task) ->
        sum + if task.show_task && task.state == "completed" then 1 else 0
      , 0

    totalVisibleTasks = (workstream, state) ->
      return (workstream.total_tasks - workstream.completed_tasks_count) if !workstream.tasks && state == 'in_progress'
      return workstream.completed_tasks_count if !workstream.tasks && state == 'completed'

      workstream.tasks.reduce (sum, task) ->
        sum + if task.show_task then 1 else 0
      , 0

    vm.workstreamProgress = (workstream) ->
      if vm.display_task == "incomplete"
        I18n.t('board.tasks.progress', incomplete: completedVisibleTasks(workstream, 'in_progress'), total: totalVisibleTasks(workstream, 'in_progress'))
      else if vm.display_task == "completed"
        I18n.t('board.tasks.progress', incomplete: completedVisibleTasks(workstream, 'completed'), total: totalVisibleTasks(workstream, 'completed'))
      else
        I18n.t('board.tasks.progress', incomplete: workstream.completed_tasks_count, total: workstream.total_tasks)

    vm.displayWorkstream = () ->
      vm.select_workstream = !vm.select_workstream

    filterWorkstreams = (filter)->
      vm.workstreams.forEach (workstream) ->
        if filter == "incomplete" && workstream.outstanding_tasks_count == 0
          workstream.show_workstream = false

        else if filter == "completed" && workstream.completed_tasks_count == 0
          workstream.show_workstream = false

        else
          workstream.show_workstream = true

    filterTasks = (workstream, filter) ->
      workstream.tasks.forEach((task) ->
        if filter == "incomplete" && task.state != 'in_progress'
          task.show_task = false

        else if filter == "completed" && task.state != 'completed'
          task.show_task = false

        else
          task.show_task = true
      ) if workstream.tasks

    filterWorkstreams(vm.display_task)

    vm.stopClick = (e) ->
      if jQuery(e.target).is('.label-checkbox-std__indicator') || jQuery(e.target).is('input[type=checkbox]')
        e.stopImmediatePropagation()
        return false
      return true

    vm.updateTask = (workstream, task, e)->
      return if vm.stopClick(e)
      return if jQuery(e.target).is('.label-checkbox-std__indicator')
      TaskUserConnectionResource
        .update(task)
        .$promise
        .then ->
          Notification.success(
            title: I18n.t('notifications.success')
            message: I18n.t('notifications.admin.tasks.updated')
          )
          updateWorkstream(workstream)
          updateUser()


      vm.updateOverdueTasks()
      vm.updateTasksCount()

    vm.enableTaskAssign = (task) ->
      task.isAssign = true

    vm.disableTaskAssign = (task) ->
      task.isAssign = false

    vm.isAssigned = (task)->
      if task.owner_id
        return true
      else
        return false

    vm.searchOwner = ($select) ->
      term = $select.search

      if term
        AdminUserResource
        .query(term: term)
        .$promise
        .then (users) ->
          $select.users = users
      else
        $select.users = []

    vm.searchWorkstream = ($select) ->
      term = $select.search
      if term
        AdminWorkstreamResource
        .query(term: term)
        .$promise
        .then (workstreams) ->
          $select.workstreams = workstreams
      else
        $select.workstreams = []

    vm.setOwner = (task, owner) ->
      task.owner = owner
      task.owner_id = owner.id
      vm.disableTaskAssign(task)
      vm.updateConnection(task)

    vm.sendActivitiesEmail = ->
      AdminUserResource.send_tasks_email(id: vm.employee.id, workstream_id: vm.current_ws)
        .$promise
        .then (response) ->
          Notification.success(
            title: I18n.t('notifications.success')
            message: I18n.t('notifications.admin.workstreams.activities_email', sent_email_count: response.sent_email_count, first_name: vm.employee.first_name, last_name: vm.employee.last_name)
          ) if response.sent_email_count
      vm.current_ws = null

    vm.addWorkstream = (workstream) ->
      $uibModal.open (
        windowTemplateUrl: 'templates/directives/ng_confirm/window.html'
        templateUrl: 'templates/directives/ng_confirm/modal.html'
        windowClass: 'activities-modal'
        controller: 'CustomConfirmController'
        resolve:
          message: -> I18n.t('confirms.email_activities')
          scope: -> vm
          cancel_text: -> I18n.t('custom_confirm.reject')
      ) if vm.current_user.new_activity_email
      vm.current_ws = workstream.id
      index = vm.workstreams.indexOf( $filter('filter')(vm.workstreams, {id: workstream.id}, true)[0])
      vm.loadTasks(vm.workstreams[index]) if index > -1

      TaskResource
        .query(workstream_id: workstream.id)
        .$promise
        .then (tasks) ->
          if !tasks.length
            Notification.error(
              title: I18n.t('validation.cant_be_blank')
              message: I18n.t('notifications.admin.workstreams.empty')
            )
            return
          assigned_tasks = []
          tasks.forEach (task)->
            if index < 0 || !$filter('filter')(vm.workstreams[index].tasks, { task_id: task.id }, true).length
              if vm.employee.id == vm.current_user.id && vm.current_user.role != 'employee'
                if task.task_type == 'hire'
                  task.task_user_connection = {_create: true}
                  assigned_tasks.push(task)
                else if task.task_type == 'owner' && task.owner_id == vm.employee.id
                  task.task_user_connection = {_create: true}
                  assigned_tasks.push(task)
              else
                if task.task_type == 'manager' && vm.employee.manager_id
                  task.task_user_connection = {_create: true}
                  assigned_tasks.push(task)
                else if task.task_type == 'hire'
                  task.task_user_connection = {_create: true}
                  assigned_tasks.push(task)
                else if task.task_type == 'buddy'
                  task.task_user_connection = {_create: true}
                  assigned_tasks.push(task)
                else if task.task_type == 'owner' && task.owner_id
                  task.task_user_connection = {_create: true}
                  assigned_tasks.push(task)
          if assigned_tasks.length
            vm.employee.is_onboarding = true
            AdminTaskUserConnectionResource
              .assign(user_id: vm.employee.id, tasks: assigned_tasks, non_onboarding: true)
              .$promise
              .then ->
                vm.employee.is_onboarding = true
                if vm.display_task == "employee"
                  vm.workstream_loading = true
                  loadEmployees()
                else if vm.display_task == "due_date"
                  vm.workstream_loading = true
                  loadDueDates()
                else
                  vm.workstream_loading = true
                  loadWorkstreams()

                Notification.success(
                  title: I18n.t('notifications.success')
                  message: I18n.t('notifications.admin.workstreams.added')
                )
      vm.select_workstream = false

    vm.removeOwner = (task) ->
      task.owner = null
      task.owner_id = null
      vm.enableTaskAssign(task)

    vm.updateConnectionValidateDate = (task, workstream, method_name) ->
      if method_name == 'change' && task.due_date && task.due_date != ''
        task.is_custom_due_date = true
        vm.updateConnection(task, workstream)
      else
        $timeout((-> task._display_deadline = false), 350)

    vm.updateConnection = (task, workstream) ->
      TaskUserConnectionResource
        .update(task)
        .$promise
        .then ->
          Notification.success(
            title: I18n.t('notifications.success')
            message: I18n.t('notifications.admin.tasks.updated')
          )
          updateWorkstream(workstream) if workstream
          updateUser()
          task._display_deadline = false

    vm.update = (task) ->
      AdminTaskResource
        .update(task)
        .$promise
        .then ->
          Notification.success(
            title: I18n.t('notifications.success')
            message: I18n.t('notifications.admin.tasks.updated')
          )

    vm.toggleDeadlineDisplay = (task) ->
      task._display_deadline = !task._display_deadline

    vm.uploadAttachment = (task_user_connection, file) ->
      return unless file

      options =
        url: '/api/v1/uploaded_files'
        method: 'POST'
        data:
          type: 'attachment'
        file: file

      Upload
        .upload(options)
        .then (response) ->
          task_user_connection.attachments ?= []
          task_user_connection.attachments.push(response.data) if response.status == 201

          task_user_connection.task.attachments = task_user_connection.attachments
          vm.update(task_user_connection.task)

    vm.removeAttachment = (task_user_connection, attachment) ->
      index = task_user_connection.attachments.indexOf(attachment)
      task_user_connection.attachments.splice(index, 1) if index > -1

      task_user_connection.task.attachments = task_user_connection.attachments
      vm.update(task_user_connection.task)

    vm.openProfile = (user_id) ->
      $rootScope.http_loading = true
      $state.go('employee_profile', id: user_id) if user_id

    vm.checkAccordion = (task) ->
      if task.is_open == false
        task._display_deadline = false

angular
  .module('Sapling')
  .controller('TasksController', [
    '$rootScope',
    'Template',
    'TaskUserConnectionResource',
    'TaskResource',
    'Notification',
    'AdminWorkstreamResource',
    'AdminTaskResource',
    'AdminUserResource',
    'AdminTaskUserConnectionResource',
    'Upload',
    '$filter',
    '$q',
    '$environment',
    'WorkstreamResource',
    '$timeout',
    'TaskUserConnectionPaginatedResource',
    'UserResource',
    '$state',
    '$uibModal'
    TasksController
  ])
