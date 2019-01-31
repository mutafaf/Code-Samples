class UsersCollection < BaseCollection
  private

  def relation
    @relation ||= User.all.includes(:profile_image)
  end

  def ensure_filters
    superuser_filter
    email_filter
    company_filter
    activated_company_filter
    personal_email_filter
    email_or_personal_email_filter
    registered_filter
    manager_filter
    buddy_filter
    role_filter
    employee_type_filter
    team_filter
    people_filter
    location_filter
    group_filter
    name_filter
    exclude_by_ids_filter
    just_before_date_filter
    recent_employees_filter
    current_stage_filter
    no_department_filter
    no_location_filter
    preferred_name_filter
    permission_term_filter
    creator_filter
    current_stage_offboarding_filter
    current_stage_offboarded_filter
    current_stage_offboarding_weekly_filter
    current_stage_offboarding_monthly_filter
    state_filter
    pre_start_filter
    first_week_filter
    first_month_filter
    ramping_up_filter
  end

  def superuser_filter
    filter { |relation| relation.where(super_user: false) }
  end

  def activated_company_filter
    filter { |relation| relation.joins(:company).where(companies: {deleted_at: nil}) }
  end

  def creator_filter
    filter { |relation| relation.where(created_by_id: params[:created_by_id], state: :new).order(updated_at: :desc)} if params[:created_by_id]
  end

  def email_filter
    filter { |relation| relation.where(email: params[:email]) } if params[:email]
  end

  def manager_filter
    filter { |relation| relation.where(manager_id: params[:manager_id]) } if params[:manager_id]
  end

  def buddy_filter
    filter { |relation| relation.where(buddy_id: params[:buddy_id]) } if params[:buddy_id]
  end

  def company_filter
    filter { |relation| relation.where(company_id: params[:company_id]) } if params[:company_id]
  end

  def personal_email_filter
    filter { |relation| relation.where(personal_email: params[:personal_email]) } if params[:personal_email]
  end

  def email_or_personal_email_filter
    filter do |relation|
      relation.where('email = :email OR personal_email = :email',
        email: params[:email_or_personal_email])
    end if params[:email_or_personal_email]
  end

  def registered_filter
    filter { |relation| relation.with_state(:registered) } if params[:registered]
  end

  def role_filter
    filter { |relation| relation.where(role: params[:role]) } if params[:role]
  end

  def employee_type_filter
    filter { |relation| relation.where(employee_type: params[:employee_type]) } if params[:employee_type]
  end

  def team_filter
    filter { |relation| relation.where(team_id: params[:team_id]) } if params[:team_id]
  end

  def people_filter
    filter do |relation|
      relation.where.not(state: ['new', 'offboarded']).where("state  = 'registered' OR state = 'offboarding' OR start_date <= ?", Date.today).order('first_name ASC')
    end if params[:people]
  end

  def location_filter
    filter { |relation| relation.where(location_id: params[:location_id]) } if params[:location_id]
  end

  def recent_employees_filter
    filter do |relation|
      relation.where(
        '((outstanding_tasks_count > 0 OR (incomplete_paperwork_count + incomplete_upload_request_count) > 0 OR outstanding_outcome_count > 0 OR start_date > :ago) AND (state != :newState AND state != :offState AND state != :userState))',
        ago: Sapling::Application::ONBOARDING_DAYS_AGO,
        newState: 'new',
        offState: 'offboarded',
        userState: 'offboarding',
      ).order('start_date DESC','first_name')
    end if params[:recent_employees]
  end

  def just_before_date_filter
    filter { |relation| relation.where('users.start_date <= ?', params[:just_before_date]).order(start_date: :desc) } if params[:just_before_date]
  end

  def name_filter
    filter do |relation|
      pattern = "%#{params[:term].to_s.downcase}%"

      name_query = 'concat_ws(\' \', lower(first_name), lower(last_name)) LIKE ?'

      relation.where("#{name_query}", pattern).where.not(state: ['new', 'offboarded'])
    end if params[:term]
  end

  def permission_term_filter
    filter do |relation|
      pattern = "%#{params[:permission_term].to_s.downcase}%"

      name_query = 'concat_ws(\' \', lower(first_name), lower(last_name)) LIKE ?'

      relation.where("#{name_query}", pattern)
    end if params[:permission_term]
  end

  def no_department_filter
    filter { |relation| relation.where(team_id: nil).where.not(state: 'offboarded') } if params[:no_department]
  end

  def no_location_filter
    filter { |relation| relation.where(location_id: nil).where.not(state: 'offboarded') } if params[:no_location]
  end

  def exclude_by_ids_filter
    filter { |relation| relation.where.not(id: params[:exclude_ids]) } if params[:exclude_ids]
  end

  def group_filter
    filter { |relation| relation.joins(:group_user_connections).where(group_user_connections: {group_id: params[:group_id]}) } if params[:group_id]
  end

  def current_stage_filter
    filter { |relation| relation.where(current_stage: params[:current_stage]) } if params[:current_stage]
  end

  def preferred_name_filter
    filter { |relation| relation.where(preferred_name: params[:preferred_name]) } if params[:preferred_name]
  end

  def current_stage_offboarding_filter
    filter { |relation| relation.where("state = ? or current_stage = ?", 'offboarded',params[:current_stage_offboarding]) } if params[:current_stage_offboarding]
  end

  def current_stage_offboarded_filter
    filter { |relation| relation.where(state: 'offboarded') } if params[:current_stage_offboarded]
  end

  def current_stage_offboarding_weekly_filter
    filter { |relation| relation.where("current_stage = :currentStage and termination_date - :currentDate < 8 and termination_date - :currentDate > 0",
                                        currentStage: params[:current_stage_offboarding_weekly],
                                        currentDate: Time.now.to_date
                                      )
    } if params[:current_stage_offboarding_weekly]
  end

  def current_stage_offboarding_monthly_filter
    filter { |relation| relation.where("current_stage = :currentStage and termination_date - :currentDate < 30 and termination_date - :currentDate > 0",
                                        currentStage: params[:current_stage_offboarding_monthly],
                                        currentDate: Time.now.to_date
                                      )
    } if params[:current_stage_offboarding_monthly]
  end

  def state_filter
    filter { |relation| relation.where(state: params[:state]) } if params[:state]
  end

  def pre_start_filter
    filter { |relation| relation.where("state = 'registered' AND start_date > ?", Date.today) } if params[:pre_start]
  end

  def first_week_filter
    filter { |relation| relation.where("state = 'registered' AND start_date < ? AND start_date > ?", Date.today, 7.days.ago) } if params[:first_week]
  end

  def first_month_filter
    filter { |relation| relation.where("state = 'registered' AND start_date < ? AND start_date > ?", Date.today, 30.days.ago) } if params[:first_month]
  end

  def ramping_up_filter
    filter { |relation| relation.where("state = 'registered' AND start_date < ?", 30.days.ago) } if params[:ramping_up]
  end

end
