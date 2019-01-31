module Api
  module V1
    class UsersController < ApiController
      before_action :require_company!
      before_action :authenticate_user!

      load_and_authorize_resource

      def index
        collection = UsersCollection.new(collection_params)
        respond_with collection.results, each_serializer: UserSerializer::Short
      end

      def limited_users
        collection = UsersCollection.new(collection_params)
        respond_with collection.results, each_serializer: UserSerializer::People
      end

      def show
        respond_with @user, serializer: UserSerializer::Full, include: '**'
      end

      def home_user
        respond_with @user, serializer: UserSerializer::Home
      end

      def roadmap_user
        respond_with @user, serializer: UserSerializer::WithRoadmap
      end

      def update
        user = UserForm.new(params)
        user.save!
        render json: user.record, serializer: UserSerializer::Full, include: '**'
      end

      def paginated
        collection = UsersCollection.new(collection_params)
        if params[:basic]
          respond_with collection.results, each_serializer: UserSerializer::People, meta: {count: collection.count}, adapter: :json
        else
          respond_with collection.results, each_serializer: UserSerializer::Dashboard, meta: {count: collection.count}, adapter: :json
        end
      end

      def user_activity_stream
        respond_with @user, serializer: UserSerializer::ActivityStream
      end

      private

      def collection_params
        params.merge(company_id: current_company.id)
      end
    end
  end
end
