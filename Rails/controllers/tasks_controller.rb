module Api
  module V1
    class TasksController < ApiController
      before_action :require_company!
      before_action :authenticate_user!

      def index
        collection = TasksCollection.new(collection_params)
        respond_with collection.results, each_serializer: TaskSerializer::WithConnections, user_id: params[:user_id], owner_id: params[:owner_id]
      end

      def update
        save_respond_with_form
      end

      private

      def save_respond_with_form
        form = TaskForm.new(task_params)
        form.save!
        respond_with form.task, serializer: TaskSerializer::WithConnections
      end

      def task_params
        params.merge({company_id: current_company.id})
      end

      def collection_params
        params.merge(company_id: current_company.id)
      end
    end
  end
end
