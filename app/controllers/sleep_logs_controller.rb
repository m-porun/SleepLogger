class SleepLogsController < ApplicationController
  # before_action :set_sleep_logs, only: [:show, :edit, :update] いつか使うかも？

  def index # 表示用
    # 年月を選択した場合、その月の日付・曜日を取得 / 今月の日付を取得
    if params[:year_month].present?
      year, month = params[:year_month].split("-").map(&:to_i) # year-month(YYYY-MM)を分割し、整数に変換
      @selected_date = Date.new(year, month, 1) # 選択された年月
    else
      @selected_date = Date.today # パラメーターがからの場合は現在の年月を入れる
    end

    @start_date = @selected_date.beginning_of_month
    @end_date = @selected_date.end_of_month

    # データベースに保存されているその月日のデータのみを取得
    @sleep_logs = current_user.sleep_logs.where(date: @start_date..@end_date)

    # 日付範囲内で SleepLog が存在しない日を作成
    (@start_date..@end_date).each do |date|
      sleep_log = @sleep_logs.find_by(date: date) || current_user.sleep_logs.create(date: date)
      sleep_log.create_awakening(awakenings_count: 0) unless sleep_log.awakening
      sleep_log.create_napping_time(napping_time: 0) unless sleep_log.napping_time
      sleep_log.create_comment(comment: "") unless sleep_log.comment
    end

    # 存在しない部分も含めて再度データを取得する
    @sleep_logs = current_user.sleep_logs.where(date: @start_date..@end_date)

    respond_to do |format| # Turbo Streamのリクエストに対応する
      format.html # いつもの表示
      format.turbo_stream { render turbo_stream: turbo_stream.replace("sleep-logs-table", partial: "logs_table") }
    end

    # 保存後、リダイレクトなどを追加
    # redirect_to sleep_logs_path, notice: 'データが保存されました'
  end

  def edit
    @sleep_log = SleepLog.find(params[:id])
    @default_date = params[:date].present? ? Date.parse(params[:date]) : Date.today

    # if turbo_frame_request?
    #   render partial: 'form', locals: { sleep_log: @sleep_log }, layout: false
    # else
    #   render :edit
    # end
    # respond_to do |format|
    #   format.html { render :edit }
    #   format.turbo_stream { render partial: 'sleep_logs/form', locals: { sleep_log: @sleep_log } }
    # end
  end

  def show
  end

  def new
  end

  def create
  end

  def update
  #   @sleep_log = current_user.sleep_logs.find(params[:id])

  #   # セッションに変更を一時保存（DBには保存しない）
  #   session[:sleep_logs_changes] ||= {}
  #   session[:sleep_logs_changes][@sleep_log.id] = sleep_log_params

  #   respond_to do |format|
  #     format.html { redirect_to sleep_logs_path, notice: "睡眠記録が一時保存されました" }
  #     format.turbo_stream do
  #       render turbo_stream: turbo_stream.replace("sleep-log-#{@sleep_log.id}", partial: "sleep_logs/log_row", locals: { sleep_log: @sleep_log })
  #     end
  #   end
  # end

  # def bulk_update
  #   # セッションから変更内容を取り出し、データベースに一括保存
  #   if session[:sleep_logs_changes].present?
  #     session[:sleep_logs_changes].each do |id, changes|
  #       sleep_log = current_user.sleep_logs.find(id)
  #       sleep_log.update(changes)
  #     end
  #     session[:sleep_logs_changes] = nil # 変更後はセッションをクリア
  #     redirect_to sleep_logs_path, notice: "全ての睡眠記録が保存されました"
  #   else
  #     redirect_to sleep_logs_path, alert: "保存する変更がありませんでした"
  #   end
  end

  def destroy
  end

  private

  def sleep_log_params
    params.require(:sleep_log).permit(:fell_asleep_at, :woke_up_at, :go_to_bed_at, :leave_bed_at, :awakening_count, :napping_time, :comment)
  end
end
