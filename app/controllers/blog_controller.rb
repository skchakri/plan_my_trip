class BlogController < ApplicationController
  skip_before_action :authenticate_user!
  layout "marketing"

  def index
    @posts = BlogPost.all
  end

  def show
    # RecordNotFound renders a 404; a controller-raised RoutingError would
    # bubble to a 500 in production (it's only mapped to 404 from the router).
    @post = BlogPost.find(params[:slug]) or raise ActiveRecord::RecordNotFound, "Post not found"
    @related = BlogPost.all.reject { |p| p.slug == @post.slug }.first(2)
  end
end
