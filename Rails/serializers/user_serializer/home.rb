module UserSerializer
  class Home < People
    attributes :outstanding_outcome_count, :incomplete_documents_count, :role, :location_id,
               :email, :phone_number, :employee_type, :outstanding_owner_outcome_count,
               :peer_onboardings, :preferred_name, :is_form_completed_by_manager, :co_signer_paperwork_count

    has_one :location, serializer: LocationSerializer::Short
    has_one :team, serializer: TeamSerializer::Short
    has_one :profile
    has_one :manager, serializer: UserSerializer::People
    has_one :account_creator, serializer: UserSerializer::People
    has_many :managed_users, serializer: UserSerializer::People

    def incomplete_documents_count
      object.incomplete_upload_request_count + object.incomplete_paperwork_count
    end

    def peer_onboardings
      peers = (object.managed_users + object.outcome_users).uniq
      peers.delete_if{ |x| x.id == object.id || x.roadmap_id == nil }
      ActiveModelSerializers::SerializableResource.new(peers, each_serializer: UserSerializer::WithRoadmap)
    end
  end
end
