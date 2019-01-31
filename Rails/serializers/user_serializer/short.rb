module UserSerializer
  class Short < ActiveModel::Serializer
    attributes :id, :first_name, :last_name, :name, :title, :role, :state, :picture, :onboard_email,
               :email, :last_activity_at, :start_date, :bio, :team_id, :location_id, :manager_id, :outstanding_tasks_count,
               :tasks_count, :roadmap_id, :is_task_overdue, :overdue_tasks, :phone_number, :tasks_owner_count, :is_onboarding,
               :employee_type, :roadmap, :termination_date, :bamboo_id, :last_changed, :roadmap_progress,
               :buddy_id, :current_stage, :company_subdomain, :outstanding_owner_tasks_count, :personal_email,
               :outstanding_owner_outcome_count, :preferred_name, :profile_name, :preboarding_progress, :account_creator_id

    has_one :location, serializer: LocationSerializer::Basic
    has_one :profile
    has_one :profile_image
    has_one :roadmap, serializer: RoadmapSerializer::WithoutUsers

    def company_subdomain
      object.company.subdomain if object.company
    end

    def name
      return object.full_name
    end

    def profile_name
      return object.first_name + ' (' + object.preferred_name + ') ' + object.last_name if object.preferred_name.present?
      return object.full_name
    end

    def is_onboarding
      object.onboarding?
    end

    def is_task_overdue
      object.task_user_connections.each do |tuc|
        if tuc.task.deadline_in && tuc.state == 'in_progress' && (object.start_date + tuc.task.deadline_in) < Date.today
          return true
        end
      end

      false
    end

    def overdue_tasks
      count = 0
      task_owner_connections = TaskUserConnection.where(owner_id: object.id).select(:task_id, :state).distinct
      task_owner_connections.each do |tuc|
        if tuc.state == 'in_progress' && (tuc.task.created_at + tuc.task.deadline_in.to_i.days) < Date.today
          count += 1
        end
      end

      count
    end

    def tasks_owner_count
      TaskUserConnection.where(owner_id: object.id).count
    end

    def last_activity_at
      if object.offboarding?
        I18n.t('models.user.last_activity_at.offboarding')
      elsif object.offboarded?
        I18n.t('models.user.last_activity_at.offboarded')
      elsif object.new?
        I18n.t('models.user.last_activity_at.incomplete')
      elsif object.invited?
        I18n.t('models.user.last_activity_at.invited')
      elsif object.preboarding?
        I18n.t('models.user.last_activity_at.preboarding')
      elsif object.onboarding?
        now = Date.today
        if object.start_date > now
          I18n.t('models.user.last_activity_at.pre-start')
        elsif object.start_date+7 > now
          I18n.t('models.user.last_activity_at.first-week')
        elsif object.start_date+30 > now
          I18n.t('models.user.last_activity_at.first-month')
        else
          I18n.t('models.user.last_activity_at.ramping-up')
        end
      elsif object.registered? && object.last_sign_in_at.blank?
        I18n.t('models.user.last_activity_at.no_activity')
      else
        object.last_sign_in_at.try(:strftime,'%d-%b-%Y')
      end
    end

    def roadmap_progress
      return 0  if !object.roadmap
      compeleted_outcomes = Outcome.joins(:user_outcome_connections)
                                   .where(user_outcome_connections: {user_id: object.id, state: 'completed'})
                                   .count
      total_outcomes = Outcome.joins(:user_outcome_connections)
                              .where(user_outcome_connections: {user_id: object.id})
                              .count

      if total_outcomes > 0
        (((compeleted_outcomes.to_f/total_outcomes).abs) *100).round
      else
        0
      end
    end
  end
end
