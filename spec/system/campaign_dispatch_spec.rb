require "rails_helper"

RSpec.describe "Campaign dispatch", type: :system do
  it "paints recipient rows and the progress metrics live as the fan-out runs", :js do
    campaign = create(:campaign, :with_recipients, recipients_count: 2)
    # Deterministic, fast child workers: no real latency, no random failures.
    allow_any_instance_of(DeliverNotificationJob).to receive(:sleep)
    allow_any_instance_of(DeliverNotificationJob).to receive(:delivery_failed?).and_return(false)

    visit campaign_path(campaign)

    expect(page).to have_content("Sent 0 of 2")
    expect(page).to have_button("Start dispatch")
    expect(page).to have_css("li", text: "Queued", count: 2)

    click_button "Start dispatch"

    # The fan-out runs on the async adapter; Turbo streams each row and the
    # metric panel onto the page. Capybara's waiting matchers absorb the timing.
    expect(page).to have_content("Sent 2 of 2", wait: 30)
    expect(page).to have_content("Completed")
    expect(page).to have_css("li", text: "Sent", count: 2)
    expect(page).not_to have_button("Start dispatch")
  end

  it "opens a campaign from the dashboard list (no Turbo frame trap)", :js do
    campaign = create(:campaign, :with_recipients, recipients_count: 1, title: "Clickable Campaign")

    visit root_path
    click_link "Clickable Campaign"

    expect(page).to have_current_path(campaign_path(campaign))
    expect(page).to have_content("Clickable Campaign")
    expect(page).not_to have_content("Content missing")
  end
end
