class User < ActiveRecord::Base
  devise :database_authenticatable, :trackable, :recoverable, :omniauthable, :lockable,
         :registerable, authentication_keys: [:email], :omniauth_providers => [:google_oauth2]

  include DeviseTokenAuth::Concerns::User
  attr_accessor :invited_employee, :updated_from

  after_update :lock_user, if: :failed_attempts_changed?
  before_create :initialize_preboarding_progress

  NULL_ATTRS = %w( email personal_email )
  before_save :nil_if_blank

  belongs_to :company, counter_cache: true
  counter_culture :company, column_name: proc {|model| model.people_validate? ? 'people_count' : nil },
                         column_names: {["users.super_user = false AND users.state != 'new' AND users.state != 'offboarded' AND (users.state = 'registered' OR users.state = 'offboarding' OR users.start_date <= ?) ", Date.today] => 'people_count'}
  belongs_to :team, counter_cache: true
  counter_culture :team, column_name: proc {|model| model.people_validate? ? 'people_count' : nil },
                         column_names: {["users.super_user = false AND users.state != 'new' AND users.state != 'offboarded' AND (users.state = 'registered' OR users.state = 'offboarding' OR users.start_date <= ?) ", Date.today] => 'people_count'}
  belongs_to :location, counter_cache: true
  counter_culture :location, column_name: proc {|model| model.people_validate? ? 'people_count' : nil },
                         column_names: {["users.super_user = false AND users.state != 'new' AND users.state != 'offboarded' AND (users.state = 'registered' OR users.state = 'offboarding' OR users.start_date <= ?) ", Date.today] => 'people_count'}
  belongs_to :manager, class_name: 'User'
  belongs_to :buddy, class_name: 'User'
  belongs_to :account_creator, class_name: 'User'
  belongs_to :roadmap

  has_many :groups, foreign_key: :owner_id, dependent: :destroy
  has_many :tasks, foreign_key: :owner_id, dependent: :destroy
  has_many :managed_users, -> { where.not(state: ['new', 'offboarded'])}, class_name: 'User', foreign_key: :manager_id, dependent: :nullify
  has_many :buddy_users, class_name: 'User', foreign_key: :buddy_id, dependent: :nullify
  has_many :account_created_users, class_name: 'User', foreign_key: :account_creator_id, dependent: :nullify
  has_many :teams, foreign_key: :owner_id, dependent: :nullify
  has_many :locations, foreign_key: :owner_id, dependent: :nullify
  has_many :assignees, -> { where.not(state: ['new', 'offboarded']).reorder('').group(:id) }, through: :task_user_connections, source: :owner
  has_many :user_assignees, -> { where.not(state: ['new', 'offboarded']).reorder('').group(:id) }, through: :task_owner_connections, source: :user
  has_many :outcome_assignees, -> { where.not(state: ['new', 'offboarded']).reorder('').group(:id) }, through: :user_outcome_connections, source: :owner
  has_many :user_outcome_assignees, -> { where.not(state: ['new', 'offboarded']).reorder('').group(:id) }, through: :owner_outcome_connections, source: :user
  has_many :outcome_users, -> { where.not(state: ['new', 'offboarded']).reorder('').group(:id) }, through: :owner_outcome_connections, source: :user
  has_many :paperwork_requests, dependent: :destroy
  has_many :assigned_paperwork_requests, -> { where("paperwork_requests.state <> ?", "draft") }, through: :paperwork_requests, source: :user
  has_many :paperwork_requests_to_co_sign, class_name: 'PaperworkRequest', foreign_key: :co_signer_id, dependent: :nullify
  has_many :outstanding_paperwork_requests, -> (object) { where(state: 'assigned')}, class_name: 'PaperworkRequest', foreign_key: :user_id
  has_many :user_document_connections, dependent: :destroy
  has_many :custom_field_values, dependent: :nullify
  has_many :outcomes, dependent: :destroy
  has_many :user_outcome_connections, dependent: :destroy
  has_many :owner_outcome_connections, class_name: 'UserOutcomeConnection', foreign_key: :owner_id, dependent: :nullify
  has_many :outstanding_outcome_owner_connections, -> (object) { where("user_outcome_connections.state = ?", 'in_progress').joins(:user).where.not(users: {state: ['new', 'offboarded'] } ) }, class_name: 'UserOutcomeConnection', foreign_key: :owner_id
  has_many :outstanding_user_outcome_connections, -> (object) { where("user_outcome_connections.state = ?", 'in_progress').joins("INNER JOIN users ON users.id = user_outcome_connections.owner_id AND users.state <> 'new' ") }, class_name: 'UserOutcomeConnection', foreign_key: :user_id

  has_many :invites, dependent: :destroy
  has_many :task_user_connections, dependent: :destroy
  has_many :task_owner_connections, class_name: 'TaskUserConnection', foreign_key: :owner_id, dependent: :destroy
  has_many :outstanding_task_owner_connections, -> (object) { where("task_user_connections.state = ?", 'in_progress').joins(:user).where("users.state NOT IN ('new', 'offboarded') AND (users.outstanding_tasks_count > 0 OR (users.incomplete_paperwork_count + users.incomplete_upload_request_count) > 0 OR users.outstanding_outcome_count > 0 OR users.start_date > ?)", Sapling::Application::ONBOARDING_DAYS_AGO) }, class_name: 'TaskUserConnection', foreign_key: :owner_id
  has_many :outstanding_task_user_connections, -> (object) { where("task_user_connections.state = ?", 'in_progress') }, class_name: 'TaskUserConnection', foreign_key: :user_id
  has_many :group_user_connections, dependent: :destroy
  has_one :profile_image, as: :entity, dependent: :destroy,
                          class_name: 'UploadedFile::ProfileImage'
  has_one :owned_company, foreign_key: :owner_id, class_name: 'Company'
  has_one :represent_company, foreign_key: :representative_id, class_name: 'Company'
  has_one :profile, dependent: :destroy
  has_many :created_users, :class_name => "User", :foreign_key => "created_by_id"
  belongs_to :creator, :class_name => "User", :foreign_key => "created_by_id"
  has_many :special_document_upload_requests, foreign_key: :special_user_id, class_name: 'DocumentUploadRequest', dependent: :destroy
  has_many :document_upload_requests, through: :user_document_connections
  has_many :outstanding_upload_requests, -> (object) { where(state: 'request') }, class_name: 'UserDocumentConnection', foreign_key: :user_id
  has_many :histories, dependent: :destroy
  has_many :history_users, dependent: :destroy

  after_create :create_profile
  before_save :updated_current_stage, if: Proc.new { |u| u.state_changed? || ( u.sign_in_count_changed? && u.sign_in_count == 1) }
  before_update :destroy_user_outcome_connections, if: :roadmap_id_changed?
  after_update :preboarding_finished, if: Proc.new { |u| u.state_changed? && u.registered? }
  after_update :add_employee_to_integrations, if: Proc.new { |u| u.current_stage_changed? && (u.current_stage == 'pre_start' || u.current_stage == 'first_week' || u.current_stage == 'first_month' || u.current_stage == 'ramping_up') }
  after_update :create_user_outcome_connections, if: :roadmap_id_changed?
  after_update :manager_email,:sync_namely_manager, if: Proc.new { |u| !u.new? && !u.offboarded? && u.manager_id && u.manager_id_changed? }
  after_update :buddy_email,  if: Proc.new { |u| !u.new? && !u.offboarded? && u.buddy_id && u.buddy_id_changed? }
  after_update :fix_counters, if: :current_state_changed?
  after_update :create_outcome_connections, if: Proc.new { |u| (u.buddy_id_changed? && u.buddy_id_was == nil) || (u.manager_id_changed? && u.manager_id_was == nil) }
  validates :password, length: { in: 8..128 }, if: Proc.new { |u| u.password.present? }
  after_update :onboarding_finished, if: Proc.new { |u| u.current_stage_changed? && !u.onboarding_completed && (u.current_stage == 'no_activity' || u.current_stage == 'registered') }
  after_update :notify_account_creator_about_manager_form_completion, if: Proc.new { |u| u.is_form_completed_by_manager_changed? && u.is_form_completed_by_manager == 'completed' }
  after_update :add_employee_to_adp_workforce_now, if: Proc.new { |u| (u.current_stage != 'offboarding' && u.current_stage != 'offboarded' && u.current_stage != 'incomplete' && u.current_stage != 'preboarding' && u.current_stage != 'invited' && u.current_stage != 'no_activity') && (u.email_was.blank?) }
  after_update :add_employee_to_paylocity, if: Proc.new { |u| u.state_changed? && u.state == 'registered' }

  enum role: { employee: 0, admin: 1, account_owner: 2 }
  enum onboard_email: { personal: 0, company: 1, both: 2 }
  enum employee_type: { full_time: 0, part_time: 1, temporary: 2, contract: 3, intern: 4, contractor: 5, internship: 6, terminated: 7, freelance: 8, consultant: 9 }
  enum current_stage: { invited: 0, preboarding: 1, pre_start: 2, first_week: 3, first_month: 4, ramping_up: 5,
                        offboarding: 6, offboarded: 7, incomplete: 8, not_onboarded: 9, onboarding: 10,
                        registered: 11, no_activity: 12 }
  enum is_form_completed_by_manager: { no_fields: 0, incompleted: 1, completed: 2 }
  enum created_by_source: { sapling: 0, namely: 1, bamboo: 2 }


  StateMachines::Machine.ignore_method_conflicts = true
  state_machine :state, initial: :new do
    after_transition :set_user_current_stage
    after_transition on: :offboarding, do: :fix_counters
    after_transition on: :offboarded, do: :fix_offboarded_counters

    event :invite do
      transition new: :invited
    end

    event :preboarding do
      transition invited: :preboarding
    end

    event :register do
      transition preboarding: :registered
    end

    event :offboarding do
      transition new: :offboarding
    end

    event :offboarded do
      transition new: :offboarded
    end

    event :offboarding do
      transition registered: :offboarding
    end

    event :offboarded do
      transition registered: :offboarded
    end

    event :offboarded do
      transition offboarding: :offboarded
    end

    event :offboarded do
      transition invited: :offboarded
    end

    event :offboarding do
      transition invited: :offboarding
    end

    event :offboarding do
      transition preboarding: :offboarding
    end

    event :offboarded do
      transition preboarding: :offboarded
    end
  end

  def user_activities_count
    count = self.paperwork_requests.count + self.user_document_connections.count + self.co_signer_paperwork_count
    count += self.task_user_connections.joins("INNER JOIN users ON users.id = task_user_connections.owner_id AND users.state <> 'new'").count
    count += self.user_outcome_connections.joins("INNER JOIN users ON users.id = user_outcome_connections.owner_id AND users.state <> 'new'").count
    count
  end

  def user_documents_count
    self.document_upload_requests.count + self.assigned_paperwork_requests.count + self.co_signer_paperwork_count
  end

  def user_tasks_count
    self.task_user_connections.count
  end

  def user_outcomes_count
    self.user_outcome_connections.count
  end

  def owner_activities_count
    count = self.paperwork_requests.count + self.user_document_connections.count + self.co_signer_paperwork_count
    count += self.task_owner_connections.joins(:user).where.not(users: {state: 'new'}).count
    count += self.owner_outcome_connections.joins(:user).where.not(users: {state: 'new'}).count
    count
  end

  def current_state_changed?
    self.state_changed? && ( self.invited? || self.registered? )
  end

  def initialize_preboarding_progress
    self.preboarding_progress = {
      welcome: false,
      our_story: false,
      our_people: false,
      about_you: false,
      wrapup: false
    }
  end

  def enable_document_notification
    self.update(document_seen: false)
  end

  def people_validate?
    self.super_user == false && self.state != 'new' && self.state != 'offboarded' && ( self.state == 'registered' || self.state == 'offboarding' || self.start_date <= Date.today)
  end

  def people_validate_changed?
    self.state_changed?
  end

  def full_name
    [self.first_name, self.last_name].compact.reject(&:blank?) * ' '
  end

  def create_profile
    self.build_profile.save!
  end

  def employee?
    role == "employee"
  end

  def onboarding_finished
    if !self.onboarding?
      self.onboarding_completed = true
      self.save!
    end
  end

  def preboarding_finished
    Interactions::Users::PreboardingCompleteEmail.new(self).perform if self.email_enabled?
  end

  def create_outcome_connections
    Interactions::Users::CreateMissingOutcomeConnections.new(self).perform
  end

  def offboard_user(task_ids=nil)
    if self.termination_date.present?
      if self.termination_date < Date.today && self.outstanding_user_outcome_connections.count <= 0 && self.outstanding_task_user_connections.count <= 0 && self.outstanding_paperwork_requests.count <= 0 && self.outstanding_upload_requests.count <= 0
        self.offboarded
        self.location_id = nil
        self.manager_id = nil
        self.buddy_id = nil
        self.outcomes.update_all(user_id: nil)
        self.tasks.update_all(owner_id: nil)

      else
        Interactions::Users::OffboardingTasks.new(self, task_ids).perform if task_ids && self.email_enabled?
        self.offboarding
      end

      self.save
    end
  end

  def picture
    if profile_image.present? && profile_image.file.present?
      profile_image.file_url :thumb
    else
      nil
    end
  end

  def original_picture
    if profile_image.present? && profile_image.file.present?
      profile_image.file_url
    else
      nil
    end
  end

  def onboarding?
    self.outstanding_tasks_count > 0 || (self.incomplete_upload_request_count + self.incomplete_paperwork_count) > 0 || self.outstanding_outcome_count > 0 || self.start_date > Sapling::Application::ONBOARDING_DAYS_AGO
  end

  def set_user_current_stage
    self.updated_current_stage
    self.save!
  end

  def fix_counters
    Interactions::Users::FixUserCounters.new(self, true).perform
  end

  def fix_offboarded_counters
    Interactions::Users::FixUserCounters.new(self).perform
  end

  def updated_current_stage
    if self.offboarding?
      self.current_stage = 'offboarding'
    elsif self.offboarded?
      self.current_stage = 'offboarded'
    elsif self.new?
      self.current_stage = 'incomplete'
    elsif self.invited?
      self.current_stage = 'invited'
    elsif self.preboarding?
      self.current_stage = 'preboarding'
    elsif self.onboarding?
      now = Date.today
      if self.start_date > now
        self.current_stage = 'pre_start'
      elsif self.start_date+7 > now
        self.current_stage = 'first_week'
      elsif self.start_date+30 > now
        self.current_stage = 'first_month'
      else
        self.current_stage = 'ramping_up'
      end
    elsif self.registered? && self.last_sign_in_at.blank?
      self.current_stage = 'no_activity'
    else
      self.current_stage = 'registered'
    end
  end

  def add_employee_to_integrations
    add_employee_to_bamboo()
    add_employee_to_namely()
    add_employee_to_adp_workforce_now()
  end

  def add_employee_to_bamboo
    if !self.bamboo_id.present?
      bamboo = Integrations::Bamboo::PushUser.new(self)
      bamboo.create_profile()
    end
  end

  def add_employee_to_paylocity
    SendEmployeeToPaylocityJob.perform_later(self)
  end

  def add_employee_to_adp_workforce_now
    SendEmployeeToAdpWorkforceNowJob.perform_later(self) if !self.adp_workforce_now_id.present? && self.email.present?
  end

  def destroy_user_outcome_connections
    UserOutcomeConnection.where(user_id: self.id).destroy_all
  end

  def create_user_outcome_connections
    roadmap = Roadmap.find_by_id(self.roadmap_id)
    roadmap_milestone_ids  = roadmap.roadmap_milestone_connections.pluck(:roadmap_milestone_id) if roadmap
    roadmap_milestone_ids.each do |roadmap_milestone_id|
      Interactions::UserOutcomeConnections::Assign::new(roadmap_milestone_id).perform
    end if roadmap_milestone_ids
  end

  def add_employee_to_namely
    SendEmployeeToNamelyJob.perform_later(self) if !self.namely_id.present?
  end

  def notify_account_creator_about_manager_form_completion
    Interactions::Users::NotifyAccountCreatorAboutManagerFormCompletionEmail.new(self, self.manager, self.account_creator).perform if self.account_creator && self.email_enabled?
  end

  def manager_email
    Interactions::Users::ManagerBuddyEmail.new(self, self.manager, 'Manager').perform if self.email_enabled?
  end


  def buddy_email
    Interactions::Users::ManagerBuddyEmail.new(self, self.buddy, self.company.buddy).perform if self.email_enabled?
  end

  def email_enabled?
    !(self.updated_from.present? && self.updated_from == 'integration')
  end

  def lock_user
    if !self.access_locked? && self.failed_attempts == 3 && (self.role == 'admin' || self.role == 'account_owner')
      self.lock_access!
    end
  end

  protected

  def nil_if_blank
    NULL_ATTRS.each { |attr| self[attr] = nil if self[attr].blank? }
  end
end
