module UserSerializer
  class Dashboard < People

    attributes :start_date, :current_stage, :location_id, :team_id, :incomplete_documents_count, :complete_documents_count,
               :tasks_count, :outstanding_tasks_count, :total_tasks_count, :outstanding_outcome_count, :total_outcomes_count,:overdue_tasks_count,
               :progress, :termination_date, :co_signer_paperwork_count, :overdue_outcomes_count

    has_one :team, serializer: TeamSerializer::Short
    has_one :location, serializer: LocationSerializer::Short
    has_many :task_user_connections, serializer: TaskUserConnectionSerializer::Short

    def incomplete_documents_count
      object.incomplete_upload_request_count + object.incomplete_paperwork_count + object.co_signer_paperwork_count
    end

    def complete_documents_count
      object.user_documents_count - incomplete_documents_count
    end

    def total_tasks_count
      object.user_tasks_count
    end

    def total_outcomes_count
      object.user_outcomes_count
    end

    def overdue_tasks_count
      TaskUserConnection.joins("INNER JOIN users ON users.id = task_user_connections.owner_id AND users.state NOT IN ('new', 'offboarded') ")
                        .where("user_id = ? AND task_user_connections.state = 'in_progress' AND due_date < ?", object.id, Date.today)
                        .count
    end

    def overdue_outcomes_count
      UserOutcomeConnection.joins("INNER JOIN users ON users.id = user_outcome_connections.owner_id AND users.state NOT IN ('new', 'offboarded') ")
                            .where("user_id = ? AND user_outcome_connections.state = 'in_progress' AND deadline_in < ?", object.id, Date.today - object.start_date )
                            .count
    end

    def progress
      tasks = object.task_user_connections.joins("INNER JOIN users ON users.id = task_user_connections.owner_id AND users.state NOT IN ('new', 'offboarded')").count
      docs = object.document_upload_requests.count
      doc_reqs = object.paperwork_requests.count
      outcomes = object.user_outcome_connections.count
      activites = tasks + doc_reqs + docs + outcomes

      activites_done = activites - (object.outstanding_tasks_count + incomplete_documents_count + object.outstanding_outcome_count)
      perc = 100
      perc = (activites_done.to_f / activites) * 100 if activites > 0
      perc
    end

  end
end
