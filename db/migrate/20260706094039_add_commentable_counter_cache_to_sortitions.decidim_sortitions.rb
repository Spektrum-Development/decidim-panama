# frozen_string_literal: true

# This migration comes from decidim_sortitions (originally 20200827154036)
class AddCommentableCounterCacheToSortitions < ActiveRecord::Migration[5.2]
  class Sortition < ActiveRecord::Base
    self.table_name = "decidim_sortitions_sortitions"

    has_many :comments, class_name: "Decidim::Comments::Comment", as: :commentable, dependent: :destroy

    def update_comments_count
      update!(comments_count: comments.size)
    end
  end

  def change
    add_column :decidim_sortitions_sortitions, :comments_count, :integer, null: false, default: 0
    add_index :decidim_sortitions_sortitions, :comments_count
    Sortition.reset_column_information
    Sortition.find_each(&:update_comments_count)
  end
end
