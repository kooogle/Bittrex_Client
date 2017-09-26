class Blocks::PointsController < Blocks::BaseController
  before_action :set_point, only:[:edit, :update, :destroy, :change_state]

  def index
    @points = Point.paginate(page:params[:page])
  end

  def new
    @point = Point.new
  end

  def create
    @point = Point.new(point_params)
    if @point.save
      redirect_to blocks_points_path, notice: '新焦点添加成功'
    else
      flash[:warn] = "请完善表单信息"
      render :new
    end
  end

  def edit
  end

  def update
    if @point.update(point_params)
      redirect_to blocks_points_path, notice: '焦点更新成功'
    else
      flash[:warn] = "请完善表单信息"
      render :edit
    end
  end

  def destroy
    @point.destroy
    flash[:notice] = "焦点删除成功"
    redirect_to :back
  end

  def change_state
    if @point.state
      @point.state = false
      @point.save
    else
      @point.state = true
      @point.save
    end
    render json:{code:200}
  end

  private
    def set_point
      @point = Point.find(params[:id])
    end

    def point_params
      params.require(:point).permit(:chain_id,:weights,:total_amount,:total_value,:unit,:state)
    end
end