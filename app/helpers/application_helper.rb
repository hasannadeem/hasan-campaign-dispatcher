module ApplicationHelper
  # A <time> element showing a relative age ("3 minutes ago") with the exact
  # timestamp on hover. Returns nil for a blank time so it renders nothing.
  def relative_time(time)
    return if time.blank?

    tag.time("#{time_ago_in_words(time)} ago",
             datetime: time.iso8601,
             title: time.strftime("%b %-d, %Y at %-l:%M %p"))
  end
end
