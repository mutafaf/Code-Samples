module UserSerializer
  class Full < Short
    attributes :location_id, :team_id, :incomplete_documents_count,
               :roadmap_completed, :outstanding_outcome_count, :current_stage, :peer_onboardings,
               :is_representative, :user_activities_count, :owner_activities_count, :created_at,
               :co_signer_paperwork_count, :google_auth_enable, :is_form_completed_by_manager, :new_activity_email

    has_one :team, serializer: TeamSerializer::Short
    has_one :manager, serializer: UserSerializer::Short
    has_one :buddy, serializer: UserSerializer::Short
    has_many :managed_users, serializer: UserSerializer::Short
    has_many :buddy_users, serializer: UserSerializer::Short

    def user_activities_count
      object.user_activities_count
    end

    def owner_activities_count
      object.owner_activities_count
    end

    def is_representative
      if object.represent_company
        true
      else
        false
      end
    end

    def roadmap_completed
      return false unless object.roadmap

      outcomes = Outcome.joins(:user_outcome_connections)
                        .where(user_outcome_connections: {user_id: object.id, state: 'in_progress'})

      if outcomes.count > 0
        false
      else
        true
      end
    end

    def peer_onboardings
      peers = (object.managed_users + object.outcome_users).uniq
      peers.delete_if{ |x| x.id == object.id || x.roadmap_id == nil || !x.onboarding?}
      ActiveModelSerializers::SerializableResource.new(peers, each_serializer: UserSerializer::WithRoadmap)
    end

    def incomplete_documents_count
      object.incomplete_upload_request_count + object.incomplete_paperwork_count
    end

    def google_auth_enable
      integration = object.company.integrations.find_by(api_name: "google_auth")
      google_auth_enable = false

      google_auth_enable = true if integration && integration.is_enabled

      google_auth_enable
    end

    def new_activity_email
      object.company.new_tasks_emails
    end
  end
end
