require "rails_helper"
require "tempfile"

RSpec.describe "Campaign management", type: :system do
  it "creates a campaign with a message and pasted recipients" do
    visit root_path

    fill_in "Title", with: "Launch Announcement"
    fill_in "Message", with: "Hi {{name}}, big news!"
    fill_in "campaign_recipients_text", with: "Ada Lovelace, ada@example.com\nGrace Hopper, grace@example.com"
    click_button "Create campaign"

    expect(page).to have_content("Campaign created with 2 recipient(s)")
    expect(page).to have_content("Launch Announcement")
    expect(page).to have_content("Hi Ada Lovelace, big news!") # rendered {{name}} preview
    expect(page).to have_css("li", text: "ada@example.com")
  end

  it "searches and filters the campaign list on the dashboard", :js do
    create(:campaign, title: "Spring Reviews", status: :pending)
    create(:campaign, title: "Winter Promo", status: :completed)

    visit root_path

    fill_in "q", with: "spring"
    expect(page).to have_content("Spring Reviews")
    expect(page).to have_no_content("Winter Promo")

    fill_in "q", with: ""
    expect(page).to have_content("Winter Promo") # wait for the cleared search to settle

    find("label", text: "Completed").click
    expect(page).to have_content("Winter Promo")
    expect(page).to have_no_content("Spring Reviews")
  end

  it "filters recipients within a campaign", :js do
    campaign = create(:campaign)
    campaign.recipients.create!(name: "Ada Lovelace", email: "ada@example.com", status: :sent)
    campaign.recipients.create!(name: "Grace Hopper", email: "grace@example.com", status: :failed)

    visit campaign_path(campaign)

    fill_in "rq", with: "lovelace"
    expect(page).to have_content("ada@example.com")
    expect(page).to have_no_content("grace@example.com")

    fill_in "rq", with: ""
    expect(page).to have_content("grace@example.com")

    find("label", text: "Failed").click
    expect(page).to have_content("grace@example.com")
    expect(page).to have_no_content("ada@example.com")
  end

  it "retries failed recipients back to sent", :js do
    campaign = create(:campaign, :with_recipients, recipients_count: 3, status: :completed)
    campaign.update_columns(processed_count: 2, failed_count: 1)
    recipients = campaign.recipients.order(:id).to_a
    recipients.first(2).each { |r| r.update_column(:status, Recipient.statuses[:sent]) }
    recipients.last.update_column(:status, Recipient.statuses[:failed])

    allow_any_instance_of(DeliverNotificationJob).to receive(:sleep)
    allow_any_instance_of(DeliverNotificationJob).to receive(:delivery_failed?).and_return(false)

    visit campaign_path(campaign)
    expect(page).to have_content("Sent 2 of 3")

    click_button "Retry 1 failed recipient"

    expect(page).to have_content("Sent 3 of 3", wait: 30)
    expect(page).to have_css("li", text: "Sent", count: 3)
  end

  it "uploads recipients via the CSV tab", :js do
    with_csv("name,email\nNoor Hassan,noor@example.com\npablo@example.com\n") do |path|
      visit root_path

      fill_in "Title", with: "CSV Campaign"
      click_button "Upload CSV"
      attach_file "campaign_recipients_csv", path, make_visible: true
      click_button "Create campaign"

      expect(page).to have_content("Campaign created with 2 recipient(s)")
      expect(page).to have_content("noor@example.com")
      expect(page).to have_content("pablo@example.com")
    end
  end

  it "bulk imports campaigns from a CSV" do
    csv = "title,name,email\nMarch Onboarding,Ines,ines@example.com\nMarch Onboarding,Diego,diego@example.com\nWebinar,Greta,greta@example.com\n"

    with_csv(csv) do |path|
      visit import_campaigns_path
      attach_file "file", path
      click_button "Import"

      expect(page).to have_content("Imported 2 campaign(s) and 3 recipient(s)")
      expect(page).to have_content("March Onboarding")
      expect(page).to have_content("Webinar")
    end
  end

  def with_csv(content)
    file = Tempfile.new([ "qa", ".csv" ])
    file.write(content)
    file.rewind
    yield file.path
  ensure
    file&.close!
  end
end
