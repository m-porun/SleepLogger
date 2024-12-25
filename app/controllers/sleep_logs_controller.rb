class SleepLogsController < ApplicationController

  def index # 表示用
    @selected_date = params[:year_month] ? Date.parse(params[:year_month] + "-01") : Date.today # 年月選択時に１日をつける。なければ本日の日付
    @start_date = @selected_date.beginning_of_month # 1日or本日の日付の月初を設定
    @end_date = @selected_date.end_of_month # 1日or本日の月末を設定
    @sleep_logs = current_user.sleep_logs.where(date: @start_date..@end_date).includes(:awakening, :napping_time, :comment) # 子クラスを含むsleep_logモデルを月初〜月末分取得する


    # # 年月を選択した場合、その月の日付・曜日を取得 / 今月の日付を取得
    # if params[:year_month].present?
    #   year, month = params[:year_month].split("-").map(&:to_i) # year-month(YYYY-MM)を分割し、整数に変換
    #   @selected_date = Date.new(year, month, 1) # 選択された年月
    # else
    #   @selected_date = Date.today # パラメーターが空の場合は現在の年月を入れる
    # end

    # @start_date = @selected_date.beginning_of_month
    # @end_date = @selected_date.end_of_month

    # # データベースに保存されているその月日のデータのみを取得
    # @sleep_logs = current_user.sleep_logs.where(date: @start_date..@end_date)

    # # 日付範囲内で SleepLog が存在しない日を作成
    # (@start_date..@end_date).each do |date|
    #   sleep_log = @sleep_logs.find_or_create_by(date: date)
    #   sleep_log.awakening ||= sleep_log.create_awakening(date: date, awakenings_count: 0) # 子モデルawakeningが存在しなければ0回を作る
    #   sleep_log.napping_time ||= sleep_log.create_napping_time(date: date, napping_time: 0) # 子モデルnapping_times
    #   sleep_log.comment ||= sleep_log.create_comment(date: date, comment: "") # 子モデルcomments
    # end

    # # 存在しない部分も含めて再度データを取得する
    # @sleep_logs = current_user.sleep_logs.where(date: @start_date..@end_date)

    respond_to do |format| # Turbo Streamのリクエストに対応する
      format.html # いつもの表示
      format.turbo_stream { render turbo_stream: turbo_stream.replace("sleep-logs-table", partial: "logs_table") }
    end

    # 保存後、リダイレクトなどを追加
    # redirect_to sleep_logs_path, notice: 'データが保存されました'
  end

  def edit
    # @sleep_log = SleepLog.find(params[:id])
    # @default_date = params[:date].present? ? Date.parse(params[:date]) : Date.today

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
    # 月初と月末の日付をprivateで設定
    start_of_month, end_of_month = date_range

    if params[:sleep_logs]
      params[:sleep_logs].each do |id, attributes| # レコードのidと、attributes(値)を日別で登録していく id作られてなかったらupdateできない
        sleep_log = current_user.sleep_logs.find_by(id: id) # その日のid
        next unless sleep_log # 入力されていなかった場合は止まらず次に進む
        next if sleep_log.date < start_of_month || sleep_log.date > end_of_month # 月初から月末までの日付以外はスキップ
        sleep_log.update(attributes.permit(:go_to_bed_at, :fell_asleep_at, :woke_up_at, :leave_bed_at))
        sleep_log.awakening&.update(attributes.permit(:awakenings_count))
        sleep_log.napping_time&.update(attributes.permit(:napping_time))
        sleep_log.comment&.update(attributes.permit(:comment))
      end
    end
    redirect_to sleep_logs_path, notice: "記録を保存しました"
  end
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
  # end

  def destroy
  end

  private

  def sleep_log_params
    params.require(:sleep_log).permit(
      :date,
      :fell_asleep_at, :woke_up_at, :go_to_bed_at, :leave_bed_at,
      awakening_attributes: [:id, :awakening_count],
      napping_time_attributes: [:id, :napping_time],
      comment_attributes: [:id, :comment]
    )
  end

  def date_range # 月初から月末まで
    [Time.current.beginning_of_month.to_date, Time.current.end_of_month.to_date]
  end

  def authenticate_user! # 記録ボタンを推した時にユーザーでなければ、ログインするように促す
    unless current_user
      redirect_to new_user_session_path, alert: "ログインしてください。"
    end
  end
end
