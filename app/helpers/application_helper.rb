module ApplicationHelper
  # Extra input classes when a model attribute has validation errors, so the
  # offending field is highlighted in place (not just listed at the top).
  def input_error_classes(model, attr)
    return "" unless model.respond_to?(:errors) && model.errors[attr].present?
    " border-rose-400 ring-2 ring-rose-500/30"
  end

  # Inline, field-level error message rendered right under the input.
  def field_errors(model, attr)
    return if model.blank? || !model.respond_to?(:errors)
    msgs = model.errors[attr]
    return if msgs.blank?
    tag.p(msgs.to_sentence, class: "mt-1.5 text-xs text-rose-300", role: "alert")
  end
end
