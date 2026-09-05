class Settings::ExchangeRatesController < ApplicationController
  layout "settings"

  before_action :require_rate_manager!
  before_action :set_exchange_rate, only: %i[edit update destroy]

  def index
    @missing_exchange_rates = ExchangeRate.missing_for_family(Current.family)
    @exchange_rates = ExchangeRate.order(date: :desc, from_currency: :asc, to_currency: :asc)
    @exchange_rates = @exchange_rates.where(from_currency: params[:from].to_s.upcase) if params[:from].present?
    @exchange_rates = @exchange_rates.where(to_currency: params[:to].to_s.upcase) if params[:to].present?
    @exchange_rates = @exchange_rates.where(source: params[:source]) if params[:source].in?(ExchangeRate::SOURCES)
    @exchange_rates = @exchange_rates.where(date: params[:date]) if params[:date].present?
  end

  def new
    @exchange_rate = ExchangeRate.new(
      date: params[:date].presence || Date.current,
      from_currency: params[:from].to_s.upcase.presence,
      to_currency: params[:to].to_s.upcase.presence,
      source: "manual"
    )
  end

  def create
    @exchange_rate = ExchangeRate.find_or_initialize_by(rate_params.slice(:from_currency, :to_currency, :date))
    assign_manual_rate

    if @exchange_rate.save
      redirect_to settings_exchange_rates_path, notice: t("settings.exchange_rates.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    assign_manual_rate

    if @exchange_rate.save
      redirect_to settings_exchange_rates_path, notice: t("settings.exchange_rates.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @exchange_rate.destroy!
    redirect_to settings_exchange_rates_path, notice: t("settings.exchange_rates.deleted")
  end

  private
    def require_rate_manager!
      return if Current.user&.admin? || Current.user&.member?

      head :forbidden
    end

    def set_exchange_rate
      @exchange_rate = ExchangeRate.find(params[:id])
    end

    def rate_params
      permitted = params.require(:exchange_rate).permit(:from_currency, :to_currency, :date, :rate)
      permitted[:from_currency] = permitted[:from_currency].to_s.upcase
      permitted[:to_currency] = permitted[:to_currency].to_s.upcase
      permitted
    end

    def assign_manual_rate
      prior_source = @exchange_rate.source
      @exchange_rate.assign_attributes(rate_params.merge(source: "manual"))
      if prior_source == "provider" && @exchange_rate.previous_rate.blank?
        @exchange_rate.previous_rate = @exchange_rate.rate_was
      end
      @exchange_rate.overridden_by = Current.user
      @exchange_rate.overridden_at = Time.current
    end
end
