class Blocks::ChainsController < Blocks::BaseController
  before_action :set_chain, only:[:edit, :update, :destroy]

  def index
    @chains = Chain.named.paginate(page:params[:page])
  end

  def new
    @chain = Chain.new
  end

  def create
    @chain = Chain.new(chain_params)
    if @chain.save
      redirect_to blocks_chains_path, notice: '新区块链添加成功'
    else
      flash[:warn] = "请完善表单信息"
      render :new
    end
  end

  def edit
  end

  def update
    if @chain.update(chain_params)
      redirect_to blocks_chains_path, notice: '区块链更新成功'
    else
      flash[:warn] = "请完善表单信息"
      render :edit
    end
  end

  def destroy
    @chain.destroy
    flash[:notice] = "区块链删除成功"
    redirect_to :back
  end

  private
    def set_chain
      @chain = Chain.find(params[:id])
    end

    def chain_params
      params.require(:chain).permit(:block,:currency,:label)
    end
end