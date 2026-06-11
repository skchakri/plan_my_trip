# Pre-attach content-type screening for user uploads. `attach` on a persisted
# record saves blobs immediately (model validations don't run), so disallowed
# files must be rejected *before* attach — html/svg uploads could otherwise be
# served back with executable content.
module AttachmentFiltering
  extend ActiveSupport::Concern

  private

  # Returns the subset of +files+ whose declared content type is allowed;
  # names of the rejects go to +rejected+ for the flash message.
  def filter_allowed_files(files, allowed_types, rejected)
    files.select do |file|
      next false unless file.respond_to?(:content_type)
      if allowed_types.include?(file.content_type.to_s.downcase)
        true
      else
        rejected << file.original_filename.to_s
        false
      end
    end
  end
end
