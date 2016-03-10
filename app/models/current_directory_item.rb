class CurrentDirectoryItem < ActiveRecord::Base
  belongs_to :user
  has_one :user_stat, foreign_key: :user_id, primary_key: :user_id

  def self.headings
    @headings ||= [:likes_received,
                   :likes_given,
                   :topics_entered,
                   :topic_count,
                   :post_count,
                   :posts_read,
                   :days_visited]
  end

  def self.current_period_types
    @types ||= Enum.new(fourth_quarterly: 1,
                        third_quarterly: 2,
                        second_quarterly: 3,
                        first_quarterly: 4)
  end

  def self.refresh!
    current_period_types.each_key {|p| refresh_period!(p)}
  end

  def self.refresh_period!(current_period_type)

    # Don't calculate it if the user directory is disabled
    return unless SiteSetting.enable_user_directory?

    since = case current_period_type
            when :first_quarterly then Time.zone.now.beginning_of_year
            when :second_quarterly then (Time.zone.now.beginning_of_year + 3.months)
            when :third_quarterly then (Time.zone.now.beginning_of_year + 6.months)
            when :fourth_quarterly then (Time.zone.now.beginning_of_year + 9.months)
            else 1000.years.ago
            end

    ActiveRecord::Base.transaction do
      exec_sql "DELETE FROM current_directory_items
                USING current_directory_items di
                LEFT JOIN users u ON u.id = user_id
                WHERE di.id = current_directory_items.id AND
                      u.id IS NULL AND
                      di.current_period_type = :current_period_type", current_period_type: current_period_types[current_period_type]


      exec_sql "INSERT INTO current_directory_items(current_period_type, user_id, likes_received, likes_given, topics_entered, days_visited, posts_read, topic_count, post_count)
                SELECT
                    :current_period_type,
                    u.id,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0
                FROM users u
                LEFT JOIN current_directory_items di ON di.user_id = u.id AND di.current_period_type = :current_period_type
                WHERE di.id IS NULL AND u.id > 0
      ", current_period_type: current_period_types[current_period_type]

      exec_sql "WITH x AS (SELECT
                    u.id user_id,
                    SUM(CASE WHEN ua.action_type = :was_liked_type THEN 1 ELSE 0 END) likes_received,
                    SUM(CASE WHEN ua.action_type = :like_type THEN 1 ELSE 0 END) likes_given,
                    COALESCE((SELECT COUNT(topic_id) FROM topic_views AS v WHERE v.user_id = u.id AND v.viewed_at >= :since), 0) topics_entered,
                    COALESCE((SELECT COUNT(id) FROM user_visits AS uv WHERE uv.user_id = u.id AND uv.visited_at >= :since), 0) days_visited,
                    COALESCE((SELECT SUM(posts_read) FROM user_visits AS uv2 WHERE uv2.user_id = u.id AND uv2.visited_at >= :since), 0) posts_read,
                    SUM(CASE WHEN ua.action_type = :new_topic_type THEN 1 ELSE 0 END) topic_count,
                    SUM(CASE WHEN ua.action_type = :reply_type THEN 1 ELSE 0 END) post_count
                  FROM users AS u
                  LEFT OUTER JOIN user_actions AS ua ON ua.user_id = u.id
                  LEFT OUTER JOIN topics AS t ON ua.target_topic_id = t.id AND t.archetype = 'regular'
                  LEFT OUTER JOIN posts AS p ON ua.target_post_id = p.id
                  LEFT OUTER JOIN categories AS c ON t.category_id = c.id
                  WHERE u.active
                    AND NOT u.blocked
                    AND COALESCE(ua.created_at, :since) >= :since
                    AND t.deleted_at IS NULL
                    AND COALESCE(t.visible, true)
                    AND p.deleted_at IS NULL
                    AND (NOT (COALESCE(p.hidden, false)))
                    AND COALESCE(p.post_type, :regular_post_type) = :regular_post_type
                    AND u.id > 0
                  GROUP BY u.id)
      UPDATE current_directory_items di SET
               likes_received = x.likes_received,
               likes_given = x.likes_given,
               topics_entered = x.likes_given,
               days_visited = x.days_visited,
               posts_read = x.posts_read,
               topic_count = x.topic_count,
               post_count = x.post_count
      FROM x
      WHERE
        x.user_id = di.user_id AND
        di.current_period_type = :current_period_type AND (
        di.likes_received <> x.likes_received OR
        di.likes_given <> x.likes_given OR
        di.topics_entered <> x.likes_given OR
        di.days_visited <> x.days_visited OR
        di.posts_read <> x.posts_read OR
        di.topic_count <> x.topic_count OR
        di.post_count <> x.post_count )

      ",
                  current_period_type: current_period_types[current_period_type],
                  since: since,
                  like_type: UserAction::LIKE,
                  was_liked_type: UserAction::WAS_LIKED,
                  new_topic_type: UserAction::NEW_TOPIC,
                  reply_type: UserAction::REPLY,
                  regular_post_type: Post.types[:regular]


      if current_period_type == :all
        exec_sql <<SQL
        UPDATE user_stats s
        SET likes_given         = d.likes_given,
            likes_received      = d.likes_received,
            topic_count         = d.topic_count,
            post_count          = d.post_count

        FROM current_directory_items d
        WHERE s.user_id = d.user_id AND
              d.current_period_type = 1 AND
          ( s.likes_given         <> d.likes_given OR
            s.likes_received      <> d.likes_received OR
            s.topic_count         <> d.topic_count OR
            s.post_count          <> d.post_count
          )

SQL
      end
    end
  end
end

# == Schema Information
#
# Table name: current_directory_items
#
#  id             :integer          not null, primary key
#  current_period_type    :integer          not null
#  user_id        :integer          not null
#  likes_received :integer          not null
#  likes_given    :integer          not null
#  topics_entered :integer          not null
#  topic_count    :integer          not null
#  post_count     :integer          not null
#  created_at     :datetime
#  updated_at     :datetime
#  days_visited   :integer          default(0), not null
#  posts_read     :integer          default(0), not null
#
# Indexes
#
#  index_current_directory_items_on_period_type_and_user  (current_period_type)
#
