class SleepLogsController < ApplicationController
  # ログインしていない場合はログイン画面にリダイレクト
  before_action :authenticate_user!, only: [ :index, :new, :edit, :update, :destroy ]

  def index # 表示用
    @selected_date = params[:year_month] ? Date.parse(params[:year_month] + "-01") : Date.today # 年月選択時に１日をつける。なければ本日の日付 parseは日付を文字列から日付に変えるメソッド
    @start_date = @selected_date.beginning_of_month # 1日or本日の日付の月初を設定
    @end_date = @selected_date.end_of_month # 1日or本日の月末を設定
    sleep_logs = current_user.sleep_logs.where(date: @start_date..@end_date).includes(:awakening, :napping_time, :comment) # 子クラスを含むsleep_logモデルを月初〜月末分取得する

    all_dates = (@start_date..@end_date).to_a # 月初から月末までの範囲オブジェクトを配列にする

    # データが存在しない日は日付で埋める
    @sleep_logs = all_dates.map do |date|
      sleep_logs.find { |sleep_log| sleep_log.date == date } || current_user.sleep_logs.build(date: date)
    end

    respond_to do |format| # Turbo Streamのリクエストに対応する
      format.html # いつもの表示
      format.turbo_stream { render turbo_stream: turbo_stream.replace("sleep-logs-table", partial: "logs_table") }
    end
  end

  def new
    @sleep_log = SleepLog.new # 入力表示用
    @sleep_log.date = params[:date]
    @sleep_log.build_awakening unless @sleep_log.awakening.present? # 存在してなければbuild
    @sleep_log.build_napping_time unless @sleep_log.napping_time.present?
    @sleep_log.build_comment unless @sleep_log.comment.present?
  end

  def create
    @sleep_log = SleepLog.new(sleep_log_params) # 保存用

    %i[go_to_bed_at fell_asleep_at woke_up_at leave_bed_at].each do |column|
      time_str = params[:sleep_log][column]
      @sleep_log[column] = convert_to_datetime(time_str) if time_str.present? # String型のHH:MMが渡されたら、DateTimeに変換する
    end

    if @sleep_log.save
      redirect_to sleep_logs_path, notice: "睡眠記録を保存しました"
    else
      render :new
    end
  end

  def edit
    @sleep_log = current_user.sleep_logs.find(params[:id])
    @sleep_log.build_awakening unless @sleep_log.awakening.present? # 存在してなければbuild
    @sleep_log.build_napping_time unless @sleep_log.napping_time.present?
    @sleep_log.build_comment unless @sleep_log.comment.present?
  end

  def update
    @sleep_log = current_user.sleep_logs.find(params[:id])

    if @sleep_log.update(sleep_log_params)
      redirect_to sleep_logs_path, notice: "睡眠記録を更新しました"
    else
      render :edit
    end
  end

  def destroy
    @sleep_log = current_user.sleep_logs.find(params[:id])
    @sleep_log.destroy
    redirect_to sleep_logs_path, notice: "睡眠記録を削除しました"
  end

  private

  def sleep_log_params
    params.require(:sleep_log).permit(
      :date,
      :fell_asleep_at,
      :woke_up_at,
      :go_to_bed_at,
      :leave_bed_at,
      awakening_attributes: [ :id, :awakenings_count ],
      napping_time_attributes: [ :napping_time ],
      comment_attributes: [ :comment ]
    ).merge(user_id: current_user.id) # 誰の記録かも追加するストロングパラメーター
  end

  # 入力されたTime型をDateTime型にする
  def convert_to_datetime(time_str)
    return nil if time_str.blank? # もし時間入力がなければnilで登録
      DateTime.parse("#{params[:sleep_log][:date]} #{time_str}") # "YYYY-MM-DD + time_str: HH:MM" として保存
    rescue ArgumentError
      nil
  end
end
