class CurrentDirectoryItemsController < ApplicationController
  PAGE_SIZE = 50

  def index
    raise Discourse::InvalidAccess.new(:enable_user_directory) unless SiteSetting.enable_user_directory?

    current_period = params.require(:current_period)
    current_period_type = CurrentDirectoryItem.current_period_types[current_period.to_sym]
    raise Discourse::InvalidAccess.new(:current_period_type) unless current_period_type

    result = CurrentDirectoryItem.where(current_period_type: current_period_type).includes(:user)

    order = params[:order] || CurrentDirectoryItem.headings.first
    if CurrentDirectoryItem.headings.include?(order.to_sym)
      dir = params[:asc] ? 'ASC' : 'DESC'
      result = result.order("current_directory_items.#{order} #{dir}")
    end

    if current_period_type == CurrentDirectoryItem.current_period_types[:all]
      result = result.includes(:user_stat)
    end
    page = params[:page].to_i

    user_ids = nil
    if params[:name].present?
      user_ids = UserSearch.new(params[:name]).search.pluck(:id)
      if user_ids.present?
        # Add the current user if we have at least one other match
        if current_user && result.dup.where(user_id: user_ids).count > 0
          user_ids << current_user.id
        end
        result = result.where(user_id: user_ids)
      else
        result = result.where('false')
      end
    end

    if params[:username]
      user_id = User.where(username_lower: params[:username].to_s.downcase).pluck(:id).first
      if user_id
        result = result.where(user_id: user_id)
      else
        result = result.where('false')
      end
    end

    result = result.order('users.username')
    result_count = result.dup.count
    result = result.limit(PAGE_SIZE).offset(PAGE_SIZE * page).to_a

    more_params = params.slice(:current_period, :order, :asc)
    more_params[:page] = page + 1

    # Put yourself at the top of the first page
    if result.present? && current_user.present? && page == 0

      position = result.index {|r| r.user_id == current_user.id }

      # Don't show the record unless you're not in the top positions already
      if (position || 10) >= 10
        your_item = CurrentDirectoryItem.where(current_period_type: current_period_type, user_id: current_user.id).first
        result.insert(0, your_item) if your_item
      end

    end

    render_json_dump(directory_items: serialize_data(result, CurrentDirectoryItemSerializer),
                     total_rows_directory_items: result_count,
                     load_more_directory_items: current_directory_items_path(more_params))
  end
end