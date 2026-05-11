class BlogController < ApplicationController
  skip_before_action :authenticate_user!
  layout "marketing"

  def index
    @posts = BlogPost.all
  end

  def show
    @post = BlogPost.find(params[:slug]) or raise ActionController::RoutingError, "Post not found"
    @related = BlogPost.all.reject { |p| p.slug == @post.slug }.first(2)
  end
end
