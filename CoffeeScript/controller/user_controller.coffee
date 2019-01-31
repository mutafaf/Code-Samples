'use strict'

class UserController
  constructor: (company, ProfileResource, TaskResource, AdminUserResource, UserResource, Template, Upload, Notification,
    $rootScope, employee, locations, team, $state, $window, $q, $filter, $uibModal, custom_fields,
    AdminCustomFieldResource, CustomFieldResource, paginated_users, AdminUserPaginatedResource, LocationResource,
    PaperworkRequestResource, $environment, TaskUserConnectionResource, $location, AdminPendingHireResource) ->

    vm = @
    vm.current_user = $rootScope.user
    vm.get_task_count = 0
    vm.locations = locations
    vm.teamMates = paginated_users.users if paginated_users
    vm.total_user_count = paginated_users.meta.count if paginated_users
    vm.teamUserPage = 1
    vm.disabled_fields = company.disabled_fields
    vm.employee = employee || $rootScope.user
    vm.employee.is_profile_image_updated = false
    vm.old_manager = vm.employee.manager
    vm.in_complete_activities_count = 0
    vm.is_all_tasks_completed_message = null
    vm.in_complete_new_hire_information_form_count = 0
    vm.new_hires_form = []
    vm.date = new Date
    vm.date_state = vm.date >= moment(vm.employee.start_date).toDate()

    if vm.date_state
      vm.join_state = 'Joined'
    else
      vm.join_state = 'Joining'

    vm.panel_heights =
      activity_height: 0,
      department_height: 'auto',

    vm.profile_title = vm.employee.profile_name
    vm.employee_home_spinner = {
      'contact_detail_loader': false
      'profile_info_loader': false
      'personal_info_loader' : false
      'additional_info_loader': false
      'private_info_loader': false
    }
    vm.company = company
    $window.scrollTo(0, 0)

    vm.show_manager_select = false
    vm.loading_team_users = false
    vm.show_buddy_select = false
    vm.activity_stream = []
    vm.states = []

    $q.when(custom_fields).then ->
      vm.custom_field_sections = {
        profile:
          fields: custom_fields
      }

      angular.forEach vm.company.prefrences.default_fields, (field) ->
        vm.custom_field_sections[field.section].fields.push field if field.section == 'profile'

      vm.custom_field_sections["profile"].fields = $filter('orderBy')(vm.custom_field_sections["profile"].fields, 'position')

    vm.employee_types = [
      { id: 0, name: 'full_time' },
      { id: 1, name: 'part_time' }
    ]

    populateIntegrationUserType = ->
      if company.integration_type == 'paylocity'
        vm.employee_types = vm.employee_types.concat([{ id: 2, name: 'temporary' }, { id: 3, name: 'contract' }])
      else if company.integration_type == 'namely'
        vm.employee_types = vm.employee_types.concat([{ id: 5, name: 'contractor' }, { id: 4, name: 'intern' }, { id: 8, name: 'freelance' }])
      else if company.integration_type == 'bamboo'
        vm.employee_types = vm.employee_types.concat([{ id: 5, name: 'contractor' }, { id: 6, name: 'internship' }, { id: 2, name: 'temporary' }, { id: 7, name: 'terminated' }])
      else if company.integration_type == 'adp_wfn'
        vm.employee_types = vm.employee_types.concat([{ id: 5, name: 'contractor' }, { id: 4, name: 'intern' }, { id: 9, name: 'consultant' }, { id: 2, name: 'temporary' }])
      else if company.integration_type == 'no_integration'
        vm.employee_types = vm.employee_types.concat([{ id: 2, name: 'temporary' }, { id: 3, name: 'contract' }])
    populateIntegrationUserType()

    vm.employeeTitleLocation = ->
      if  vm.employee.location
        return vm.employee.title + " | " + vm.employee.location.name if vm.employee.title
        vm.employee.location.name
      else
        vm.employee.title if vm.employee.title

    vm.getPanelSizes = ->
      if vm.current_user.role == "account_owner" || vm.current_user.role == "admin" || vm.current_user.id == vm.employee.id
        vm.panel_heights.activity_height = angular.element('#profile').prop('offsetHeight')
      else if vm.current_user.role == "employee"
        vm.panel_heights.department_height = angular.element('#profile').prop('offsetHeight')
      true

    vm.profileFields = ->
      !vm.employee.profile.about_you && !vm.employee.profile.linkedin && !vm.employee.profile.twitter && !vm.employee.profile.github && !vm.checkCustomFormFields(vm.custom_field_sections.profile.fields)

    vm.canViewActivites = ->
      return true if vm.current_user.role == "account_owner" || vm.current_user.role == "admin" || vm.employee.id == vm.current_user.id || vm.current_user.id == vm.employee.manager_id

    loadUserActivityStream = (show_notification)->
      UserResource
        .user_activity_stream(user_id: vm.employee.id)
        .$promise
        .then (resp) ->
          activities = []
          activities = activities.concat(resp.doc) if resp.doc
          activities = activities.concat(resp.outcomes) if resp.outcomes
          activities = activities.concat(resp.tasks) if resp.tasks
          activities = activities.concat(resp.paperwork) if resp.paperwork
          activities = activities.concat(resp.employee_record_collected_by_manager) if resp.employee_record_collected_by_manager
          vm.activity_stream = $filter('orderBy')(activities, 'created_at', true)

          if resp.employee_record_collected_by_manager && resp.employee_record_collected_by_manager.length > 0
            vm.in_complete_new_hire_information_form_count =  resp.employee_record_collected_by_manager.length
            vm.new_hires_form = resp.employee_record_collected_by_manager

          Notification.success(
            title: I18n.t('notifications.success')
            message: I18n.t('employee.home.profile.activity_stream.snoozed')
          ) if show_notification

    loadUserActivityStream() if vm.canViewActivites()

    if vm.current_user.is_representative
      refresh_activities = firebase.database().ref('paperwork_request_signed/' + vm.current_user.id)
      refresh_activities.on 'value', (response)->
        if response.val()
          loadUserActivityStream()
          firebase.database().ref('paperwork_request_signed/' + vm.current_user.id).remove()
          UserResource
            .home_user(id: vm.current_user.id)
            .$promise
            .then (resp) ->
              vm.current_user.incomplete_documents_count = resp.incomplete_documents_count
              vm.current_user.owner_activities_count = resp.owner_activities_count
              vm.current_user.user_activities_count = resp.user_activities_count
              vm.current_user.co_signer_paperwork_count = resp.co_signer_paperwork_count

    vm.reloadUserAcitivityStream = ->
      loadUserActivityStream() if vm.canViewActivites()

    vm.checkCustomFormFields =  (custom_fields=[]) ->
      result = false
      sub_custom_field_result = false
      custom_fields.forEach (custom_field) ->
        sub_custom_field_result = true if vm.isSubCustomFieldValuesPresent(custom_field.sub_custom_fields)
        field_value = custom_field && custom_field.custom_field_value
        value_text = field_value && field_value.value_text
        result = true if (custom_field && field_value && (value_text || field_value.custom_field_option_id))
      return (result || sub_custom_field_result)

    vm.isSubCustomFieldValuesPresent = (sub_custom_fields = []) ->
      result = false
      sub_custom_fields.forEach (sub_custom_field) ->
        field_value = sub_custom_field && sub_custom_field.custom_field_value
        value_text = field_value && field_value.value_text
        result = true if (sub_custom_field && field_value && value_text)
      return result

    vm.team = team
    vm.manager_reports = vm.employee.managed_users
    vm.loading_team_users = false

    vm.nextTeamUserPage = ->
      if vm.team && vm.teamMates.length < vm.total_user_count
        vm.loading_team_users = true
        vm.teamUserPage += 1
        params = {
          per_page: 25
          page: vm.teamUserPage
          basic: true
          people: true
          team_id: vm.team.id
        }

        AdminUserPaginatedResource
          .query(params)
          .$promise
          .then (response) ->
            response.users.forEach (user) ->
              vm.teamMates.push user
            vm.loading_team_users = false

    vm.searchUser = ($select) ->
      term = $select.search
      if term
        UserResource
        .limited_users(term: term)
        .$promise
        .then (users) ->
          $select.users = users
      else
        $select.users = []

    vm.onManagerSave = ->
      if(vm.current_user.id == vm.employee.id)
        UserResource.update(vm.employee).$promise.then (resp) ->
          vm.employee = $rootScope.user = resp
      else
        AdminUserResource.update(vm.employee).$promise.then (resp)->
          vm.employee = resp
      Notification.success(
        title: I18n.t('notifications.success')
        message: I18n.t('notifications.employee_record.saved')
      )


    vm.getIsAllTasksCompletedMessage = ->
      vm.is_all_tasks_completed_message

    getInCompleteActivitiesCount = ->
      if vm.employee.manager_id
        TaskUserConnectionResource
          .all_completed(user_id: vm.employee.id, manager_id: vm.employee.manager_id)
          .$promise
          .then (response) ->
            vm.in_complete_activities_count = response.count

    vm.onSelectedManager = (manager)->
      if vm.in_complete_activities_count > 0
        vm.is_all_tasks_completed_message = I18n.t('employee.home.manager_confirm', in_complete_activities_count: vm.in_complete_activities_count, employee_name: vm.employee.name, old_manager_name: vm.old_manager.name, new_manager_name: manager.name)

    vm.updateManager = ->
      if vm.employee.manager && vm.employee.manager.id != vm.employee.manager_id
        vm.employee.manager_id = vm.employee.manager.id
        vm.onManagerSave()
        vm.old_manager = vm.employee.manager

      vm.show_manager_select = false

    vm.editManager = ->
      getInCompleteActivitiesCount()
      vm.show_manager_select = true

    vm.editBuddy = ->
      vm.show_buddy_select = true

    vm.updateBuddy = ->
      if vm.employee.buddy && vm.employee.buddy.id != vm.employee.buddy_id
        vm.employee.buddy_id = vm.employee.buddy.id
        vm.onManagerSave()

      vm.show_buddy_select = false

    vm.canEditForm = ->
      vm.current_user.id == vm.employee.id || vm.current_user.role == 'admin' || vm.current_user.role == 'account_owner'

    updateCustomFields = (custom_fields=[]) ->
      custom_fields.forEach (custom_field) ->
        custom_field.custom_field_value.value_text = $filter('ssn')(custom_field.custom_field_value.value_text) if (custom_field.field_type == 'social_security_number' && custom_field.custom_field_value)
        if !custom_field.isDefault
          if (vm.current_user.id == vm.employee.id)
            CustomFieldResource.update(custom_field).$promise.then (response) ->
              if custom_field.field_type == 'address'
                custom_field.sub_custom_fields = response.sub_custom_fields
              else
                custom_field.custom_field_value = response.custom_field_value
          else if(vm.current_user.role == 'admin' || vm.current_user.role == 'account_owner')
            custom_field.user_id = employee.id
            AdminCustomFieldResource.update(custom_field).$promise.then (response) ->
              if custom_field.field_type == 'address'
                custom_field.sub_custom_fields = response.sub_custom_fields
              else
                custom_field.custom_field_value = response.custom_field_value

    vm.updateAboutYou = ->
      if vm.canEditForm()
        ProfileResource.update(vm.employee.profile).$promise.then (resp) ->
          vm.employee.profile = resp
        updateCustomFields(vm.custom_field_sections.profile.fields)

    vm.getTaskCount = ->
      if vm.current_user.id == vm.employee.id || !vm.employee.is_onboarding
        vm.get_task_count = vm.employee.outstanding_owner_tasks_count
      else
        vm.get_task_count = vm.employee.outstanding_tasks_count

    vm.getTaskCount()

    vm.getOutcomeCount = ->
      if vm.current_user.id == vm.employee.id || !vm.employee.is_onboarding
        vm.employee.outstanding_owner_outcome_count
      else
        vm.employee.outstanding_outcome_count

    vm.getNewHireInformationCount = ->
      vm.in_complete_new_hire_information_form_count

    vm.getOutstandingActivitiesCount = ->
      incomplete_documents_count = if vm.employee.incomplete_documents_count < 0 then 0 else vm.employee.incomplete_documents_count
      outstanding_owner_outcome_count = if vm.employee.outstanding_owner_outcome_count < 0 then 0 else vm.employee.outstanding_owner_outcome_count
      outstanding_owner_tasks_count = if vm.employee.outstanding_owner_tasks_count <  0 then 0 else vm.employee.outstanding_owner_tasks_count
      outstanding_outcome_count = if vm.employee.outstanding_outcome_count < 0 then 0 else vm.employee.outstanding_outcome_count
      outstanding_tasks_count = if vm.employee.outstanding_tasks_count < 0 then 0 else vm.employee.outstanding_tasks_count
      co_signer_paperwork_count = if vm.employee.co_signer_paperwork_count < 0 then 0 else vm.employee.co_signer_paperwork_count

      if vm.current_user.id == vm.employee.id || !vm.employee.is_onboarding
        outstanding_owner_outcome_count + incomplete_documents_count + outstanding_owner_tasks_count + co_signer_paperwork_count + vm.in_complete_new_hire_information_form_count
      else
        outstanding_outcome_count + incomplete_documents_count + outstanding_tasks_count + co_signer_paperwork_count + vm.in_complete_new_hire_information_form_count

    vm.getIncompleteDocumentsCount = ->
      if (vm.employee.incomplete_documents_count + vm.employee.co_signer_paperwork_count) >= 0 then vm.employee.incomplete_documents_count + vm.employee.co_signer_paperwork_count else 0

    vm.getTotalActivitiesCount = ->
      if vm.current_user.id == vm.employee.id || !vm.employee.is_onboarding
        vm.employee.owner_activities_count
      else
        vm.employee.user_activities_count

    vm.hideActivity = (activity) ->
      UserResource
        .hide_activity(user_id: vm.current_user.id, activity_id: activity.id, activity_type: activity.type)
        .$promise
        .then (resp) ->
          if !activity.no_snooze
            loadUserActivityStream(true)
          else
            loadUserActivityStream()

    signDocument = (activity) ->
      PaperworkRequestResource
        .signature(id: activity.id, email: vm.current_user.email || vm.current_user.personal_email)
        .$promise
        .then (paperwork_request)->
          HelloSign.init $environment.hellosign_client_id
          HelloSign.open
            url: paperwork_request.hellosign_signature_url
            skipDomainVerification: !($environment.name == "production")
            messageListener: (eventData) ->
              if(eventData.event == "signature_request_signed")
                paperwork_request
                  .$all_signed(user_id: paperwork_request.user_id)
                  .then (resp)->
                    vm.current_user.incomplete_documents_count -=1
                    vm.current_user.owner_activities_count -=1
                    vm.current_user.user_activities_count -=1
                    $state.go('employee_record', {id: paperwork_request.user_id})

    vm.goToActivitiyPage = (activity) ->
      switch activity.type
        when 'document'
          vm.goToDocuments()
        when 'outcome'
          $state.go('board.activities',{id: activity.user_id, active_tab: 2, active_milestone_id: activity.roadmap_milestone_id})
        when 'counter_sign'
          signDocument(activity)
        when 'collect_from_manager'
          vm.showUserInformationModalRequiredByManager(activity.id)
        else
          $state.go('board.activities',{id: vm.employee.id, active_tab: 1, active_workstream_id: activity.workstream_id})

    vm.goToActivitesTab = (tab)->
      $state.go('board.activities',{id: vm.employee.id, active_tab: tab})
    vm.goToDocuments = ->
      vm.goToActivitesTab(0)
    vm.openTasksView = ->
      vm.goToActivitesTab(1)
    vm.goToUserRoadmap = ->
      vm.goToActivitesTab(2)
    vm.goToUserRecord = ->
      vm.goToActivitesTab(3)

    vm.goToMaxActivities = ->
      if vm.current_user.id == vm.employee.id || !vm.employee.is_onboarding
        if  vm.employee.incomplete_documents_count > vm.employee.outstanding_owner_outcome_count && vm.employee.incomplete_documents_count > vm.employee.outstanding_owner_tasks_count
          vm.goToDocuments()
        else if vm.employee.outstanding_owner_outcome_count > vm.employee.incomplete_documents_count && vm.employee.outstanding_owner_outcome_count > vm.employee.outstanding_owner_tasks_count
          vm.goToUserRoadmap()
        else
          vm.openTasksView()

      else
        if  vm.employee.incomplete_documents_count > vm.employee.outstanding_outcome_count && vm.employee.incomplete_documents_count > vm.employee.outstanding_tasks_count
          vm.goToDocuments()
        else if vm.employee.outstanding_outcome_count > vm.employee.incomplete_documents_count && vm.employee.outstanding_outcome_count > vm.employee.outstanding_tasks_count
          vm.goToUserRoadmap()
        else
          vm.openTasksView()

    vm.onProfileSave = ->
      if vm.canEditForm()
        vm.employee_home_spinner['profile_info_loader'] = true
        ProfileResource.update(vm.employee.profile).$promise.then (resp) ->
          vm.employee.profile = resp
          vm.employee_home_spinner['profile_info_loader'] = false
        updateCustomFields(vm.custom_field_sections.profile.fields)
        Notification.success(
          title: I18n.t('notifications.success')
          message: I18n.t('notifications.employee_record.saved')
        )


    vm.onPersonalInfoSave = ->
      vm.employee_home_spinner['personal_info_loader'] = true
      if(vm.current_user.id == vm.employee.id)
        UserResource.update(vm.employee).$promise.then (resp) ->
          vm.employee = $rootScope.user = resp
          vm.employee_home_spinner['personal_info_loader'] = false
        updateCustomFields(vm.custom_field_sections.personal_info.fields)
      else if(vm.current_user.role == 'admin' || vm.current_user.role == 'account_owner')
        AdminUserResource.update(vm.employee).$promise.then (resp)->
          vm.employee = resp
          vm.employee_home_spinner['personal_info_loader'] = false
        updateCustomFields(vm.custom_field_sections.personal_info.fields)

    vm.onPrivateInfoSave = ->
      vm.employee_home_spinner['private_info_loader'] = true
      if(vm.current_user.id == vm.employee.id)
        UserResource.update(vm.employee).$promise.then (resp) ->
          vm.employee = $rootScope.user = resp
          vm.employee_home_spinner['private_info_loader'] = false
        updateCustomFields(vm.custom_field_sections.private_info.fields)
      else if(vm.current_user.role == 'admin' || vm.current_user.role == 'account_owner')
        AdminUserResource.update(vm.employee).$promise.then (resp)->
          vm.employee = resp
          vm.employee_home_spinner['private_info_loader'] = false
        updateCustomFields(vm.custom_field_sections.private_info.fields)

    vm.onAdditionalFieldsSave = ->
      if vm.canEditForm()
        vm.employee_home_spinner['additional_info_loader'] = true
        if(vm.current_user.id == vm.employee.id || vm.current_user.role == 'admin' || vm.current_user.role == 'account_owner')
          ProfileResource.update(vm.employee.profile).$promise.then (resp) ->
            vm.employee.profile = resp
            vm.employee_home_spinner['additional_info_loader'] = false
          updateCustomFields(vm.custom_field_sections.additional_fields.fields)

    vm.onContactDetailSave = ->
      vm.employee_home_spinner['contact_detail_loader'] = true
      if(vm.current_user.id == vm.employee.id)
        UserResource.update(vm.employee).$promise.then (resp) ->
          vm.employee = $rootScope.user = resp
          vm.employee_home_spinner['contact_detail_loader'] = false
          vm.employee.is_profile_image_updated = false
      else
        AdminUserResource.update(vm.employee).$promise.then (resp)->
          vm.employee = resp
          vm.employee_home_spinner['contact_detail_loader'] = false
          vm.employee.is_profile_image_updated = false

    vm.removeProfileImage = ->
        vm.employee.profile_image.remove_file = true
        vm.employee.is_profile_image_updated = true
        vm.employee.profile_image.file = {}

    uploadFile = (type, file, base) ->
      Upload.upload
        url: '/api/v1/uploaded_files'
        method: 'POST'
        data: {type: type}
        file: file
      .then (response) =>
        if response.data.status == "invalid_size"
          Notification.error(I18n.t('admin.company.general.invalid_image_size'))
        else if response.status == 201
          vm.employee.profile_image  = response.data
          vm.employee.is_profile_image_updated = true
          vm.onContactDetailSave()

      .catch (response) =>
        Notification.error(I18n.t('admin.company.general.invalid_image_file'))

    saveFile = (type, file, invalid_files, base) ->
      if invalid_files.indexOf(file) == -1
        uploadFile(type, file, base)

    vm.upload = (type, files, invalid_files, base) =>
      if vm.canEditForm()
        if invalid_files.length
          Notification.error(I18n.t('admin.company.general.invalid_image_file'))
        if files
          saveFile(type, files, invalid_files, base)

    vm.isDisabled = (field_name)->
      vm.disabled_fields.indexOf(field_name) < 0

    vm.socialLinkURL = (socialURL, profile) =>
      return if !profile
      if profile.indexOf(socialURL) != -1
        profile
      else
        socialURL.concat(profile)

    vm.canEditAndViewForm = (head)->
      if vm.current_user.role != "employee" || vm.current_user.id == vm.employee.id || vm.current_user.id == vm.employee.manager.id
        return vm.current_user.private_info_access_level == "view_and_edit_private" if head == I18n.t('employee.home.private_info.head')
        return vm.current_user.additional_info_access_level == "view_and_edit_additional" if head == I18n.t('employee.home.additional_info.head')

    vm.canViewForm = (head)->
      if vm.current_user.role != "employee" || vm.current_user.id == vm.employee.id || vm.current_user.id == vm.employee.manager.id
        return vm.current_user.private_info_access_level == "view_private" if head == I18n.t('employee.home.private_info.head')
        return vm.current_user.additional_info_access_level == "view_additional" if head == I18n.t('employee.home.additional_info.head')

    vm.showActivitiesHelp = () ->
      $uibModal.open (
        templateUrl: 'templates/modals/activities_help_modal.html'
        windowClass: 'activities-help-modal'
      )

    vm.showUserInformationModalRequiredByManager = (id) ->
      user_id = id
      if angular.isDefined(user_id)
        UserResource.home_user(id: user_id).$promise.then (response) ->
          if response.is_form_completed_by_manager == 'incompleted'
            if response.manager_id == vm.current_user.id
              modal = $uibModal.open (
                templateUrl: 'templates/modals/information_collect_from_manager.html'
                windowClass: 'information-collect-from-manager-modal'
                controller: 'InformationCollectFromManagerController'
                controllerAs: 'information_collect_for_manager_ctrl'
                resolve:
                  company: company,
                  employee: response,
                  custom_fields: CustomFieldResource.query(user_id: user_id).$promise
              )

              modal.result.then (response) ->
                vm.activity_stream.forEach (activity) ->
                  if activity.type == 'collect_from_manager' && activity.id == response.id
                    activity.no_snooze = true
                    Notification.success(
                      title: I18n.t('notifications.success')
                      message: I18n.t('employee.home.profile.new_hire_information_completed')
                    )
                    vm.hideActivity(activity)
      $location.search({})
    vm.showUserInformationModalRequiredByManager($location.search().open_record_popup)

    vm.openMostRecentNewHireForm = () ->
      vm.showUserInformationModalRequiredByManager(vm.new_hires_form[vm.new_hires_form.length-1].id) if vm.new_hires_form.length > 0

angular
  .module('Sapling')
  .controller('UserController', [
    'company',
    'ProfileResource',
    'TaskResource',
    'AdminUserResource',
    'UserResource',
    'Template',
    'Upload',
    'Notification',
    '$rootScope',
    'employee',
    'locations',
    'team',
    '$state',
    '$window',
    '$q',
    '$filter',
    '$uibModal',
    'custom_fields',
    'AdminCustomFieldResource',
    'CustomFieldResource',
    'paginated_users',
    'AdminUserPaginatedResource',
    'LocationResource',
    'PaperworkRequestResource',
    '$environment',
    'TaskUserConnectionResource',
    '$location',
    'AdminPendingHireResource'
    UserController])
