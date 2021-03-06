require "diffa/date_aggregation"

class TradesController < ApplicationController

  include UserAuthTokenVerifier

  def propagate
    t = owned_trades_view.find(params[:trade_id])
    klass = { 'N' => Option, 'Y' => Future }.fetch(t.is_future)

    instrument = klass.create_or_update_from_trade(t)
    # render json: instrument
    render text: "Trade id #{params[:trade_id]} pushed to the downstream; please rescan to let Diffa know about the change."
  end

  def grid
    user = params[:user_id]
    trades = TradesView.where(:user => user)
    render json: trades
  end

  def scan
    user = params[:user_id]
    pp user: user, params: params
    params = request.query_parameters.reject { |param, val| param == "authToken" }

    aggregation = Diffa::DateAggregation.new(user, 'entry_date', params, {
      yearly: TradesEntryDateYearly,
      monthly: TradesEntryDateMonthly,
      daily: TradesEntryDateDaily,
      individual: TradesView,
    })
    render json: aggregation.scan
  end

  # GET /trades
  # GET /trades.json
  def index *_
    @trades = owned_trades_view

    render json: @trades
  end

  # GET /trades/1
  # GET /trades/1.json
  def show
    @trade = owned_trades_view.find(params[:id])

    # using render: @trade assumes that there is a route named trade_path,
    render json: @trade
  end

  # GET /trades/new
  # GET /trades/new.json
  def new
    @trade = Trade.new

    render json: @trade
  end

  # GET /trades/1/edit
  def edit
    @trade = owned_trades.find(params[:id])
  end

  # POST /trades
  # POST /trades.json
  def create *args
    @user = User.find(params[:user_id])
    @trade = Trade.new(params[:trade])
    @trade.user_id = @user.id

    if @trade.save
      @tradeViewRow = TradesView.find(@trade.id)
      render json: @tradeViewRow, location: user_trade_path(@user, @trade)
    else
      render action: "new"
    end
  end

  # PUT /trades/1
  # PUT /trades/1.json
  def update*args
    pp args: args

    @trade = owned_trades.find(params[:id])

    if @trade.update_attributes(params[:trade])
      @tradeViewRow = TradesView.find(@trade.id)
      render json: @tradeViewRow
    else
      render json: @trade.errors, status: :unprocessable_entity
    end
  end

  # DELETE /trades/1
  # DELETE /trades/1.json
  def destroy*args
    pp args: args

    @trade = owned_trades.find(params[:id])
    @trade.destroy

    head :no_content
  end


  def content
    pp content: params
    id_match =  /^0*(\d+)/.match(params[:identifier])

    if id_match
      trade = owned_trades.find(id_match[1])
      render text: trade.attributes.map { |k, v| "#{k}=#{v}" }.join("\n")
    else
      render status: :not_found, text: "Item #{params[:identifier].inspect} Not found"
    end
  end

  private
  def owned_trades_view
    TradesView.where(:user => params[:user_id])
  end

  def owned_trades
    Trade.where(:user_id => params[:user_id])
  end
end
