class BlogController < ApplicationController
  skip_before_action :authenticate_user!
  layout "marketing"

  def index
    @posts = BlogPost.published.recent
  end

  def show
    # find_by! raises RecordNotFound → 404, so unpublished/draft posts stay
    # private and search engines never index a redirect. The `published` scope
    # excludes drafts, archived, discarded, and future-dated posts.
    @post = BlogPost.published.find_by!(slug: params[:slug])
    @related = BlogPost.published.recent.where.not(id: @post.id).limit(2)
  end
end
