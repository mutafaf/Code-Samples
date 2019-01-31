class TaskForm < BaseForm
  presents :task

  PLURAL_RELATIONS = %i(task_user_connections)

  attribute :task_user_connections, Array[TaskUserConnectionForm]
  attribute :position, Integer
  attribute :owner_id, Integer
  attribute :workstream_id, Integer
  attribute :create_jira_issue, Boolean
end
