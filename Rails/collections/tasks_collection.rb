class TasksCollection < BaseCollection
  private

  def relation
    @relation ||= Task.all
  end

  def ensure_filters
    company_filter
    user_filter
    owner_filter
    workstream_filter
  end

  def company_filter
    filter do |relation|
      relation.joins(:workstream).where(workstreams: {company_id: params[:company_id]})
    end if params[:company_id]
  end

  def workstream_filter
    filter do |relation|
      relation.joins(:workstream).where(workstreams: {id: params[:workstream_id]})
    end if params[:workstream_id]
  end

  def user_filter
    filter do |relation|
      relation.joins(:task_user_connections).where('user_id = ?', params[:user_id])
    end if params[:user_id]
  end

  def owner_filter
    filter do |relation|
      relation.joins(:task_user_connections).where('task_user_connections.owner_id = ?', params[:owner_id])
    end if params[:owner_id]
  end
end
