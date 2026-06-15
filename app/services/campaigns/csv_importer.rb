require "csv"

module Campaigns
  # Bulk importer: ingests a `title,name,email` CSV, groups rows by campaign
  # title, and provisions one campaign per distinct title with its recipients —
  # all in a single transaction so a bad file leaves no partial state. Rows
  # missing a title or email are skipped and counted rather than aborting.
  class CsvImporter
    MAX_ROWS = 10_000

    Result = Struct.new(:campaigns_created, :recipients_created, :skipped_rows, keyword_init: true)

    def self.call(io)
      new(io).call
    end

    def initialize(io)
      @content = io.respond_to?(:read) ? io.read : io.to_s
    end

    def call
      rows, skipped = valid_rows
      campaigns_created = 0
      recipients_created = 0

      ActiveRecord::Base.transaction do
        rows.group_by { |title, _, _| title }.each do |title, group|
          campaign = Campaign.create!(title: title)
          group.each do |(_title, name, email)|
            campaign.recipients.create!(name: name, email: email)
            recipients_created += 1
          end
          campaigns_created += 1
        end
      end

      Result.new(campaigns_created:, recipients_created:, skipped_rows: skipped)
    end

    private

    def valid_rows
      parsed = CSV.parse(@content)
      return [ [], 0 ] if parsed.empty?

      parsed.shift if header?(parsed.first)
      skipped = 0

      rows = parsed.first(MAX_ROWS).filter_map do |row|
        title, name, email = row.map { |v| v.to_s.strip }

        if title.blank? || email.blank?
          skipped += 1
          next
        end

        name = email.split("@").first if name.blank?
        [ title, name, email ]
      end

      skipped += parsed.size - MAX_ROWS if parsed.size > MAX_ROWS
      [ rows, skipped ]
    end

    def header?(row)
      row.map { |v| v.to_s.strip.downcase }.first(3) == %w[title name email]
    end
  end
end
