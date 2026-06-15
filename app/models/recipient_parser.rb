# Parses the "one recipient per line" textarea into Recipient attribute hashes.
#
# Line format: `Name, email@example.com` — split on the FIRST comma so names
# may themselves contain commas. Whitespace is trimmed and blank lines skipped.
# A line with no comma is treated as a bare email, with the name defaulting to
# the email's local part (the bit before "@").
class RecipientParser
  Parsed = Struct.new(:name, :email)

  def self.parse(text)
    new(text).parse
  end

  def initialize(text)
    @text = text.to_s
  end

  def parse
    @text.each_line.filter_map do |line|
      name, email = line.split(",", 2).map(&:strip)

      if email.blank?
        email = name
        name = email.to_s.split("@").first
      end

      Parsed.new(name, email) if email.present?
    end
  end
end
