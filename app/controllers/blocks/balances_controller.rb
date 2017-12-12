class Blocks::BalancesController < Blocks::BaseController
  before_action :set_balance, only:[:edit, :update, :destroy, :all_out]

  def index
    @balances = Balance.much.paginate(page:params[:page])
  end

  def new
    @balance = Balance.new
  end

  def create
    @balance = Balance.new(balance_params)
    if @balance.save
      redirect_to blocks_balances_path, notice: '账户余额添加成功'
    else
      flash[:warn] = "请完善表单信息"
      render :new
    end
  end

  def edit
  end

  def update
    if @balance.update(balance_params)
      redirect_to blocks_balances_path, notice: '账户余额更新成功'
    else
      flash[:warn] = "请完善表单信息"
      render :edit
    end
  end

  def destroy
    @balance.destroy
    flash[:notice] = "账户余额删除成功"
    redirect_to :back
  end

  def sync
    Balance.sync
    redirect_to blocks_balances_path, warn: '账户余额同步成功'
  end

  def all_out
    if @balance.chain
      block = @balance.chain
      amount = block.balance
      price = block.market.first["Bid"]
      if amount > 0 && price > 0
        sell_chain(block,amount,price)
      end
      redirect_to blocks_balances_path, notice: '库存币种全部清仓'
    else
      redirect_to blocks_balances_path, notice: '该币种不存在'
    end
  end

  private
    def set_balance
      @balance = Balance.find(params[:id])
    end

    def balance_params
      params.require(:balance).permit(:block,:balance,:available,:pending,:address)
    end

    def sell_chain(block,amount,price)
      order = Order.new
      order.deal = 0
      order.chain_id = block.id
      order.amount = amount
      order.price = price
      order.save
    end
end