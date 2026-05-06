module HotwireNativeHelper
  HOTWIRE_NATIVE_UA = /Hotwire Native|Turbo Native/i

  def hotwire_native_app?
    request.user_agent.to_s.match?(HOTWIRE_NATIVE_UA)
  end

  def hotwire_native_platform
    return :ios if request.user_agent.to_s.match?(/iOS/i)
    return :android if request.user_agent.to_s.match?(/Android/i)
    nil
  end
end
