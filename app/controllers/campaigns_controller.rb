class CampaignsController < ApplicationController
  before_action :set_campaign, only: %i[show start retry_failed]

  def index
    @stats = DashboardStats.new
    # .load materializes the (filtered) relation once, so the view's `any?`
    # check and the collection render share a single query. Counts on the cards
    # come from counter caches, so recipients are never hit.
    @campaigns = filtered_campaigns.load
    @campaign = Campaign.new
  end

  def show
    @recipients = @campaign.recipients
                           .search(params[:rq])
                           .then { |scope| params[:rstatus].present? ? scope.where(status: params[:rstatus]) : scope }
                           .order(:id)
  end

  def create
    @campaign = Campaign.new(campaign_params)
    @campaign.recipients_text = recipients_text
    @campaign.recipients = parsed_recipients

    if @campaign.save
      redirect_to @campaign, notice: "Campaign created with #{@campaign.recipients.size} recipient(s)."
    else
      @stats = DashboardStats.new
      @campaigns = Campaign.order(created_at: :desc).load
      render :index, status: :unprocessable_content
    end
  end

  # Bulk multi-campaign import — GET renders the upload form, POST processes it.
  def import
    return unless request.post? # GET/HEAD just render the form

    file = params[:file]
    if file.blank?
      flash.now[:alert] = "Please choose a CSV file to import."
      return render :import, status: :unprocessable_content
    end

    result = Campaigns::CsvImporter.call(file.read)
    skipped = result.skipped_rows.positive? ? " (#{result.skipped_rows} row(s) skipped)" : ""
    redirect_to root_path,
      notice: "Imported #{result.campaigns_created} campaign(s) and #{result.recipients_created} recipient(s)#{skipped}."
  rescue CSV::MalformedCSVError
    flash.now[:alert] = "That file could not be parsed as CSV."
    render :import, status: :unprocessable_content
  end

  def start
    if @campaign.pending?
      DispatchCampaignJob.perform_later(@campaign.id)
      redirect_to @campaign, notice: "Dispatch started."
    else
      redirect_to @campaign, alert: "This campaign has already been dispatched."
    end
  end

  def retry_failed
    if Campaigns::RetryFailedService.new(@campaign).call
      redirect_to @campaign, notice: "Retrying failed recipients."
    else
      redirect_to @campaign, alert: "There are no failed recipients to retry."
    end
  end

  private

  def set_campaign
    @campaign = Campaign.find(params[:id])
  end

  def filtered_campaigns
    scope = Campaign.search(params[:q])
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope.order(created_at: :desc)
  end

  def campaign_params
    params.require(:campaign).permit(:title, :body)
  end

  # Recipients come from either the pasted textarea or an uploaded CSV file.
  def parsed_recipients
    parsed =
      if (file = params.dig(:campaign, :recipients_csv)).present?
        RecipientCsvParser.parse(file.read)
      else
        RecipientParser.parse(recipients_text)
      end

    parsed.map { |r| Recipient.new(name: r.name, email: r.email) }
  end

  def recipients_text
    params.dig(:campaign, :recipients_text).to_s
  end
end
