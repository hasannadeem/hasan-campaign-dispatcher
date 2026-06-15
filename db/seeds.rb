campaign = Campaign.find_or_create_by!(title: "Spring Product Reviews")

if campaign.recipients.empty?
  [
    [ "Ada Lovelace", "ada@example.com" ],
    [ "Grace Hopper", "grace@example.com" ],
    [ "Alan Turing", "alan@example.com" ],
    [ "Katherine Johnson", "katherine@example.com" ],
    [ "Linus Torvalds", "linus@example.com" ]
  ].each { |name, contact| campaign.recipients.create!(name:, contact:) }
end

puts "Seeded #{Campaign.count} campaign(s) with #{Recipient.count} recipient(s)."
