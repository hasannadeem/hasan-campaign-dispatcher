# Rich demo dataset for manual QA. Re-runnable: wipes campaigns first, then
# builds a spread of states (pending / processing / completed), failures,
# with/without message bodies, and varied titles/recipients for search testing.
#
# See QA_GUIDE.md for the scenarios each campaign is designed to exercise.

Campaign.destroy_all

FIRST = %w[Ada Grace Alan Katherine Linus Margaret Dennis Barbara Tim Anita John Radia Edsger Donald Frances Hedy Annie Shafi Karen Carl].freeze
LAST  = %w[Lovelace Hopper Turing Johnson Torvalds Hamilton Ritchie Liskov Berners-Lee Borg McCarthy Perlman Dijkstra Knuth Allen Lamarr Easley Goldwasser Spärck-Jones Sagan].freeze

# Build n unique [name, email] pairs (index-suffixed emails keep them distinct).
def people(count, domain: "example.com")
  (0...count).map do |i|
    name = "#{FIRST[i % FIRST.size]} #{LAST[i % LAST.size]}"
    [ name, "#{FIRST[i % FIRST.size].downcase}#{i + 1}@#{domain}" ]
  end
end

# Creates a campaign and distributes recipient statuses to match the given
# sent/failed counts; the remainder stay queued. Counter caches are set to match.
def make_campaign(title:, status:, count:, sent: 0, failed: 0, body: nil, domain: "example.com")
  campaign = Campaign.create!(title: title, status: status, body: body)
  people(count, domain: domain).each { |name, email| campaign.recipients.create!(name: name, email: email) }

  recipients = campaign.recipients.order(:id).to_a
  recipients.first(sent).each { |r| r.update_column(:status, Recipient.statuses[:sent]) }
  recipients[sent, failed].to_a.each { |r| r.update_column(:status, Recipient.statuses[:failed]) }
  campaign.update_columns(processed_count: sent, failed_count: failed)
  campaign
end

REVIEW_BODY  = "Hi {{name}}, thanks for your recent order — we'd love a quick review!".freeze
SURVEY_BODY  = "Hello {{name}}, do you have 2 minutes for a short survey? It really helps.".freeze
PROMO_BODY   = "{{name}}, our biggest sale of the year is here — 30% off, today only.".freeze

# --- PENDING (test: Start dispatch, live animation) ---------------------------
make_campaign(title: "Spring Product Reviews", status: :pending, count: 5, body: REVIEW_BODY)
make_campaign(title: "Winter Newsletter",      status: :pending, count: 3) # no body -> tests the no-message path

# --- COMPLETED, all sent (test: clean success, message preview) ---------------
make_campaign(title: "Q1 Customer Survey", status: :completed, count: 6, sent: 6, body: SURVEY_BODY)

# --- COMPLETED with failures (test: Retry Failed button + recovery loop) -------
make_campaign(title: "Q2 Feedback Request", status: :completed, count: 8,  sent: 6, failed: 2, body: SURVEY_BODY)
make_campaign(title: "Black Friday Promo",  status: :completed, count: 10, sent: 7, failed: 3, body: PROMO_BODY)

# --- PROCESSING snapshot (test: in-flight UI; static — won't auto-advance) -----
make_campaign(title: "Spring Flash Sale", status: :processing, count: 6, sent: 3, failed: 1, body: PROMO_BODY)

# --- Extra titles for SEARCH (multiple "Spring", distinct words) --------------
make_campaign(title: "Spring Cleaning Tips", status: :completed, count: 4, sent: 4, body: REVIEW_BODY)

# --- LARGE campaign for RECIPIENT FILTER testing (mixed @acme.com / @example.com)
make_campaign(title: "Annual Report Mailing", status: :completed, count: 25, sent: 20, failed: 5, body: SURVEY_BODY, domain: "acme.com")

puts "Seeded #{Campaign.count} campaigns and #{Recipient.count} recipients."
puts "  pending:    #{Campaign.pending.count}"
puts "  processing: #{Campaign.processing.count}"
puts "  completed:  #{Campaign.completed.count} (#{Campaign.completed.where('failed_count > 0').count} with failures → retryable)"
