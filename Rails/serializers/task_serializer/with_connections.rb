module TaskSerializer
  class WithConnections < Base
    attributes :task_user_connection, :task_user_connection_user
    has_one :user, serializer: UserSerializer::Short
    belongs_to :workstream, serializer: WorkstreamSerializer::Base

    def task_user_connection
      if instance_options[:user_id]
        object.task_user_connections.includes(:user, :owner).find_by(user_id: instance_options[:user_id])
      else
        object.task_user_connections.includes(:user, :owner).find_by(owner_id: instance_options[:owner_id])
      end
    end

    def task_user_connection_user
      UserSerializer::Short.new(task_user_connection.user) if task_user_connection
    end

    def owner
      connection = task_user_connection

      if connection
        connection.owner
      else
        object.task_type == 'owner' ? object.owner : nil
      end
    end

    def user
      task_user_connection.try(:user)
    end
  end
end
