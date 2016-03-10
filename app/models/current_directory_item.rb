class CurrentDirectoryItem < ActiveRecord::Base
  belongs_to :user
  has_one :user_stat, foreign_key: :user_id, primary_key: :user_id

  def self.headings
    @headings ||= [:topic_count,
                   :post_count,
                   :total_participation]
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


      exec_sql "INSERT INTO current_directory_items(current_period_type, user_id, topic_count, post_count, total_participation)
                SELECT
                    :current_period_type,
                    u.id,
                    0,
                    0,
                    0
                FROM users u
                LEFT JOIN current_directory_items di ON di.user_id = u.id AND di.current_period_type = :current_period_type
                WHERE di.id IS NULL AND u.id > 0
      ", current_period_type: current_period_types[current_period_type]

      exec_sql "WITH x AS (SELECT
                    u.id user_id,
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
               topic_count = x.topic_count,
               post_count = x.post_count,
               total_participation = x.topic_count + x.post_count
      FROM x
      WHERE
        x.user_id = di.user_id AND
        di.current_period_type = :current_period_type AND (
        di.topic_count <> x.topic_count OR
        di.post_count <> x.post_count )

      ",
                  current_period_type: current_period_types[current_period_type],
                  since: since,
                  new_topic_type: UserAction::NEW_TOPIC,
                  reply_type: UserAction::REPLY,
                  regular_post_type: Post.types[:regular]
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
#  topic_count    :integer          not null
#  post_count     :integer          not null
#  total_participation     :integer          not null
#  created_at     :datetime
#  updated_at     :datetime
#
# Indexes
#
#  index_current_directory_items_on_period_type_and_user  (current_period_type)
#
