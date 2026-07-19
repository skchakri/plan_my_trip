module Admin
  class BlogPostsController < BaseController
    before_action :set_post, only: %i[edit update destroy publish unpublish]

    def index
      @posts = BlogPost.kept.recent
    end

    def new
      @post = BlogPost.new(status: "draft", author_name: current_user.display_name)
    end

    def create
      @post = BlogPost.new(post_params)
      if @post.save
        redirect_to admin_blog_posts_path, notice: "Post created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @post.update(post_params)
        redirect_to admin_blog_posts_path, notice: "Post updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @post.discard
      redirect_to admin_blog_posts_path, notice: "Post removed."
    end

    def publish
      @post.update(status: "published", published_at: @post.published_at || Time.current)
      redirect_to admin_blog_posts_path, notice: "Post published."
    end

    def unpublish
      @post.update(status: "draft")
      redirect_to admin_blog_posts_path, notice: "Post unpublished."
    end

    private

    def set_post
      # BlogPost#to_param is the slug, so admin URL helpers pass the slug as :id.
      @post = BlogPost.find_by!(slug: params[:id])
    end

    def post_params
      permitted = params.require(:blog_post).permit(
        :title, :slug, :excerpt, :body, :status, :published_at,
        :cover_image_url, :author_name, :seo_description, :reading_minutes, :tags
      )
      permitted[:tags] = permitted[:tags].to_s.split(/[,\n]+/).map(&:strip).reject(&:blank?) if permitted.key?(:tags)
      permitted
    end
  end
end
