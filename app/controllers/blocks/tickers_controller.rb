class Blocks::TickersController < Blocks::BaseController
  before_action :set_chain
  before_action :set_ticker, only:[:edit, :update, :destroy]

  def index
    @tickers = Ticker.where(chain_id:@chain).latest.paginate(page:params[:page])
  end

  def new
    @ticker = Ticker.new
  end

  def create
    @ticker = Ticker.new(ticker_params)
    if @ticker.save
      redirect_to blocks_chain_tickers_path(@chain), notice: '区块行情添加成功'
    else
      flash[:warn] = "请完善表单信息"
      render :new
    end
  end

  def edit
  end

  def update
    if @ticker.update(ticker_params)
      redirect_to blocks_chain_tickers_path(@chain), notice: '区块行情更新成功'
    else
      flash[:warn] = "请完善表单信息"
      render :edit
    end
  end

  def destroy
    @ticker.destroy
    flash[:notice] = "区块行情删除成功"
    redirect_to :back
  end

  private
    def set_chain
      @chain = Chain.find(params[:chain_id])
    end

    def set_ticker
      @ticker = Ticker.find(params[:id])
    end

    def ticker_params
      params.require(:ticker).permit(:chain_id,:last_price,:buy_price,:sell_price,:ma_price,:mark)
    end
end