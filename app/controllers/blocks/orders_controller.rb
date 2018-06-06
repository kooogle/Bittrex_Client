class Blocks::OrdersController < Blocks::BaseController
  before_action :set_order, only:[:edit, :update, :destroy]

  def index
    orders = Order.all
    orders = orders.where(deal:params[:business]) if params[:business].present?
    orders = orders.where(chain_id:params[:block]) if params[:block].present?
    @total_buy = orders.where(deal:1,state:true).map {|x| x.total}.sum.round(2)
    @total_sell = orders.where(deal:0,state:true).map {|x| x.total}.sum.round(2)
    @orders = orders.latest.paginate(page:params[:page])
  end

  def new
    @order = Order.new
  end

  def create
    @order = Order.new(order_params)
    if @order.save
      redirect_to blocks_orders_path, notice: '买卖订单添加成功'
    else
      flash[:warn] = "请完善表单信息"
      render :new
    end
  end

  def edit
  end

  def update
    if @order.update(order_params)
      redirect_to blocks_orders_path, notice: '买卖订单更新成功'
    else
      flash[:warn] = "请完善表单信息"
      render :edit
    end
  end

  def destroy
    @order.destroy
    flash[:notice] = "买卖订单删除成功"
    redirect_to :back
  end

  def cancel
    Order.cancel(params[:uuid])
    Order.find_by_result(params[:uuid]).destroy rescue nil
    flash[:notice] = "买卖挂单取消交易"
    redirect_to :back
  end

  def market_price
    currency = Chain.find(params[:chain])
    render json:{amount:currency.available_amount,price:currency.market_price}
  end

  private
    def set_order
      @order = Order.find(params[:id])
    end

    def order_params
      params.require(:order).permit(:chain_id,:deal,:amount,:price,:total,:state,:frequency,:repurchase)
    end
end