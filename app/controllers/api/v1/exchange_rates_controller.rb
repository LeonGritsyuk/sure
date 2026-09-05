class Api::V1::ExchangeRatesController < Api::V1::BaseController
  before_action :ensure_read_scope, only: %i[index show missing]
  before_action :ensure_write_scope, only: %i[create update destroy]
  before_action :set_exchange_rate, only: %i[show update destroy]

  def index
    rates = ExchangeRate.order(date: :desc, from_currency: :asc, to_currency: :asc)
    rates = rates.where(from_currency: params[:from].to_s.upcase) if params[:from].present?
    rates = rates.where(to_currency: params[:to].to_s.upcase) if params[:to].present?
    rates = rates.where(source: params[:source]) if params[:source].in?(ExchangeRate::SOURCES)
    rates = rates.where(date: params[:date]) if params[:date].present?

    render json: rates.map { |rate| rate_json(rate) }
  end

  def show
    render json: rate_json(@exchange_rate)
  end

  def missing
    render json: ExchangeRate.missing_for_family(current_resource_owner.family)
  end

  def create
    @exchange_rate = ExchangeRate.find_or_initialize_by(rate_params.slice(:from_currency, :to_currency, :date))
    assign_rate(api_source)
    save_rate
  end

  def update
    assign_rate(api_source)
    save_rate
  end

  def destroy
    @exchange_rate.destroy!
    head :no_content
  end

  private
    def ensure_read_scope
      authorize_scope!(:read)
    end

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def set_exchange_rate
      @exchange_rate = ExchangeRate.find(params[:id])
    end

    def rate_params
      permitted = params.permit(:from_currency, :to_currency, :date, :rate)
      permitted[:from_currency] = permitted[:from_currency].to_s.upcase
      permitted[:to_currency] = permitted[:to_currency].to_s.upcase
      permitted
    end

    def api_source
      source = params[:source].presence || "imported"
      return source if source.in?(%w[manual imported])

      raise ActionController::BadRequest, "source must be manual or imported"
    end

    def assign_rate(source)
      prior_source = @exchange_rate.source
      @exchange_rate.assign_attributes(rate_params.merge(source: source))
      if source == "manual"
        @exchange_rate.previous_rate = @exchange_rate.rate_was if prior_source == "provider" && @exchange_rate.previous_rate.blank?
        @exchange_rate.overridden_by = current_resource_owner
        @exchange_rate.overridden_at = Time.current
      end
    end

    def save_rate
      if @exchange_rate.save
        render json: rate_json(@exchange_rate), status: :ok
      else
        render json: { error: "validation_failed", errors: @exchange_rate.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def rate_json(rate)
      {
        id: rate.id,
        from: rate.from_currency,
        to: rate.to_currency,
        date: rate.date,
        rate: rate.rate.to_f,
        source: rate.source,
        previous_rate: rate.previous_rate&.to_f,
        overridden_at: rate.overridden_at,
        overridden_by_id: rate.overridden_by_id,
        updated_at: rate.updated_at
      }
    end
end
