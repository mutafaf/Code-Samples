class UserForm < BaseForm
  presents :user

  SINGULAR_RELATIONS = %i(profile_image)

  attribute :first_name, String
  attribute :last_name, String
  attribute :email, String
  attribute :personal_email, String
  attribute :title, String
  attribute :start_date, Date
  attribute :location_id, Integer
  attribute :group_id, Integer
  attribute :manager_id, Integer
  attribute :buddy_id, Integer
  attribute :team_id, Integer
  attribute :company_id, Integer
  attribute :created_by_id, Integer
  attribute :profile_image, UploadedFileForm::ProfileImageForm
  attribute :state, String
  attribute :onboard_email, Integer
  attribute :provider, String
  attribute :uid, String
  attribute :role, Integer
  attribute :roadmap_id, Integer
  attribute :phone_number, String
  attribute :employee_type, Integer
  attribute :termination_date, Date
  attribute :current_stage, Integer
  attribute :preferred_name, String
  attribute :invited_employee, Boolean
  attribute :preboarding_progress, JSON
  attribute :is_form_completed_by_manager, Integer
  attribute :account_creator_id, Integer

  validate :company_or_personal_email?
  validate :validate_emails
  validates :company_id, :first_name, :last_name, :start_date, presence: true
  validates :email, :personal_email, email: true, uniqueness: { scope: :company_id, case_sensitive: false, model: User }, allow_blank: true

  before_validation :set_provider_and_uid
  before_validation :set_empty_as_nil

  private
  def company_or_personal_email?
    email.present? || personal_email.present?
  end

  def set_empty_as_nil
    self.personal_email = nil if personal_email == ''
    self.email = nil if email == ''
  end

  def set_provider_and_uid
    if onboard_email && ((onboard_email == 0 || onboard_email == 'personal') && personal_email)
      self.provider = 'personal_email'
      self.uid = personal_email

    elsif onboard_email && ((onboard_email == 1 || onboard_email == 'company') && email)
      self.provider = 'email'
      self.uid = email
    end
  end

  def validate_emails
    user = User.where('email = :personal_email OR email = :email OR '+
      'personal_email = :email OR personal_email = :personal_email',
      email: email, personal_email: personal_email
    )
    update_user = user.present? && user.first.id == id ? true : false
    errors.add(:Email, I18n.t('admin.people.create_profile.email_uniq')) if user.exists? && !update_user
  end
end
