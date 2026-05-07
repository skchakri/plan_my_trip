module MarkdownHelper
  def render_markdown(text)
    return "".html_safe if text.blank?
    renderer = Redcarpet::Render::HTML.new(escape_html: true, hard_wrap: true)
    Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      fenced_code_blocks: true,
      tables: true,
      strikethrough: true,
      space_after_headers: true
    ).render(text).html_safe
  end
end
