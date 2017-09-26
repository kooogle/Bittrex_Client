class Blocks::OrdersController < Blocks::BaseController
  before_action :set_order, only:[:edit, :update, :destroy]

  def index
    @orders = Order.paginate(page:params[:page])
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

  private
    def set_order
      @order = Order.find(params[:id])
    end

    def order_params
      params.require(:order).permit(:chain_id,:deal,:amount,:price,:total,:state)
    end
end