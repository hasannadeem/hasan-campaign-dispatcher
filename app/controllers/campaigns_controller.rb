class CampaignsController < ApplicationController
  before_action :set_campaign, only: %i[show start]

  def index
    @campaigns = Campaign.order(created_at: :desc)
    @campaign = Campaign.new
  end

  def show
  end

  def create
    @campaign = Campaign.new(campaign_params)
    @campaign.recipients_text = recipients_text
    @campaign.recipients = parsed_recipients

    if @campaign.save
      redirect_to @campaign, notice: "Campaign created with #{@campaign.recipients.size} recipient(s)."
    else
      @campaigns = Campaign.order(created_at: :desc)
      render :index, status: :unprocessable_content
    end
  end

  def start
    if @campaign.pending?
      DispatchCampaignJob.perform_later(@campaign)
      redirect_to @campaign, notice: "Dispatch started."
    else
      redirect_to @campaign, alert: "This campaign has already been dispatched."
    end
  end

  private

  def set_campaign
    @campaign = Campaign.find(params[:id])
  end

  def campaign_params
    params.require(:campaign).permit(:title)
  end

  def parsed_recipients
    recipients_text.each_line.filter_map do |line|
      name, contact = line.split(",", 2).map(&:strip)
      Recipient.new(name: name, contact: contact) if name.present? && contact.present?
    end
  end

  def recipients_text
    params.dig(:campaign, :recipients_text).to_s
  end
end
