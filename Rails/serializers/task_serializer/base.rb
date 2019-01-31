module TaskSerializer
  class Base < ActiveModel::Serializer
    attributes :id, :name, :description, :workstream_id, :owner_id, :deadline_in, :position,
               :task_type, :create_jira_issue

    belongs_to :owner, class_name: 'User', serializer: UserSerializer::Short
    has_many :attachments, serializer: AttachmentSerializer

  end
end
