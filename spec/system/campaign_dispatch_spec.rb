require "rails_helper"

RSpec.describe "Campaign dispatch", type: :system do
  include ActiveJob::TestHelper

  it "streams recipient status updates live as the campaign is dispatched", :js do
    campaign = create(:campaign, :with_recipients, recipients_count: 3)
    allow_any_instance_of(DispatchCampaignJob).to receive(:sleep)
    allow_any_instance_of(DispatchCampaignJob).to receive(:delivery_outcome).and_return(:sent)

    visit campaign_path(campaign)

    expect(page).to have_content("Sent 0 of 3")
    expect(page).to have_button("Start dispatch")

    perform_enqueued_jobs { click_button "Start dispatch" }

    expect(page).to have_content("Sent 3 of 3", wait: 10)
    expect(page).to have_content("Completed")
    expect(page).not_to have_button("Start dispatch")
    expect(page).to have_css("li", text: "Sent", count: 3)
  end
end
