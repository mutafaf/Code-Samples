module UserSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :first_name, :last_name
  end
end
