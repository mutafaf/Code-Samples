class Task < ActiveRecord::Base
  belongs_to :owner, class_name: 'User'
  belongs_to :workstream, counter_cache: true

  has_many :task_user_connections, dependent: :destroy
  has_many :attachments, as: :entity, dependent: :destroy,
                         class_name: 'UploadedFile::Attachment'

  accepts_nested_attributes_for :task_user_connections

  validates :name, :workstream, :deadline_in, presence: true
  validates :owner_id, presence: true, if: :task_type_owner?

  acts_as_list scope: :workstream

  enum task_type: { owner: '0', hire: '1', manager: '2', buddy: '3' }

  default_scope { order(position: :asc) }

  private
  def task_type_owner?
    task_type == 'owner'
  end
end
