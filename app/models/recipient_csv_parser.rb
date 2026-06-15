require "csv"

# Parses an uploaded CSV of recipients into Recipient attribute hashes — the CSV
# sibling of RecipientParser. Accepts an optional `name,email` header (case
# insensitive); otherwise treats the columns positionally as name, email.
# Blank rows are skipped, whitespace trimmed, and a row with only one value is
# treated as a bare email (name defaults to the local part), matching the
# textarea parser's rules.
class RecipientCsvParser
  Parsed = Struct.new(:name, :email)

  def self.parse(io)
    new(io).parse
  end

  def initialize(io)
    @content = io.respond_to?(:read) ? io.read : io.to_s
  end

  def parse
    rows.filter_map do |row|
      name, email = row.map { |v| v.to_s.strip }

      if email.blank?
        email = name
        name = email.to_s.split("@").first
      end

      Parsed.new(name, email) if email.present?
    end
  end

  private

  def rows
    parsed = CSV.parse(@content)
    return [] if parsed.empty?

    parsed.shift if header?(parsed.first)
    parsed
  rescue CSV::MalformedCSVError
    [] # a malformed upload yields no recipients rather than a 500
  end

  def header?(row)
    row.map { |v| v.to_s.strip.downcase }.first(2) == %w[name email]
  end
end
