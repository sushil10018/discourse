class CurrentDirectoryItemSerializer < ApplicationSerializer

  attributes :id,
             :time_read

  has_one :user, embed: :objects, serializer: UserNameSerializer
  attributes *CurrentDirectoryItem.headings

  def id
    object.user_id
  end

  def time_read
    AgeWords.age_words(object.user_stat.time_read)
  end

  def include_time_read?
    object.current_period_type == CurrentDirectoryItem.current_period_types[:first_quarterly]
  end

end
