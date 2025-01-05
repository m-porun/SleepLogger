class SleepLogsController < ApplicationController
  # ログインしていない場合はログイン画面にリダイレクト
  before_action :authenticate_user!, only: [ :index, :new, :edit, :update, :destroy ]

  def index # 表示用
    @selected_date = if params[:year_month]
      Date.strptime(params[:year_month] + "-01", "%Y-%m-%d") rescue Date.today # 年月選択時に１日をつける。なければ本日の日付 strptimeはparseよりも安全に日付を文字列から日付に変えるメソッド
    else
      Date.today
    end
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
    @sleep_log = SleepLog.new # ただの入力表示用
    @sleep_log.date = params[:date]
    initialize_associations(@sleep_log) # 子モデルの作成
  end

  def create
    @sleep_log = SleepLog.new(sleep_log_params) # 保存用。文字列型として渡される

    # Time型カラムをDateTime型カラムに変更する
    processed_params = sleep_log_params.dup # 入力した内容を複製して編集

    %i[go_to_bed_at fell_asleep_at woke_up_at leave_bed_at].each do |column|
      if processed_params[column].present?
        processed_params[column] = convert_to_datetime(processed_params[column], processed_params[:date]) # private内のメソッドでString型のTimeをDateTime型に変更
      end
    end

    # 覚醒時刻が就床時刻と就寝時刻よりも前の時間にならないよう2者を修正
    adjust_datetime_order(@sleep_log, processed_params) # DateTime型にした修正版睡眠記録を引数に

    # 加工したパラメーターをモデルに割り当てる
    @sleep_log.assign_attributes(processed_params)

    if @sleep_log.save
      year_month = @sleep_log.date.strftime("%Y-%m") # 登録されたsleep_log.dateをYYYY-MM形式に変換
      redirect_to sleep_logs_path(year_month: year_month), notice: "睡眠記録を保存しました"
    else
      render :new
    end
  end

  def edit
    @sleep_log = current_user.sleep_logs.find(params[:id])
    @sleep_log.date ||= params[:date]
    initialize_associations(@sleep_log) # 子モデルを探す／作成
  end

  def update
    @sleep_log = current_user.sleep_logs.find(params[:id])

    # String型のHH:MMが渡されたら、DateTimeに変換する
    processed_params = sleep_log_params.dup # 入力した内容を複製して編集

    %i[go_to_bed_at fell_asleep_at woke_up_at leave_bed_at].each do |column|
      time_str = params[:sleep_log][column]
      if time_str.present?
        datetime_value = convert_to_datetime(time_str, processed_params[:date]) # Time型のカラムと複製したDateカラムを送る
        processed_params[column] = datetime_value
      end
    end
    # 覚醒時刻が就床時刻と就寝時刻よりも前の時間にならないよう修正
    adjust_datetime_order(@sleep_log, processed_params) # DateTime型にした修正版睡眠記録を引数に

    if @sleep_log.update(processed_params) # 複製して編集した方を保存
      year_month = @sleep_log.date.strftime("%Y-%m")
      redirect_to sleep_logs_path(year_month: year_month), notice: "睡眠記録を更新しました"
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
      :go_to_bed_at,
      :fell_asleep_at,
      :woke_up_at,
      :leave_bed_at,
      awakening_attributes: [ :id, :awakenings_count ], # Unpermitted parameter: :id対策
      napping_time_attributes: [ :id, :napping_time ],
      comment_attributes: [ :id, :comment ]
    ).merge(user_id: current_user.id) # 誰の記録かも追加するストロングパラメーター
  end

  # 子モデルの作成
  def initialize_associations(sleep_log)
    @sleep_log.build_awakening unless @sleep_log.awakening.present? # 存在してなければbuild
    @sleep_log.build_napping_time unless @sleep_log.napping_time.present?
    @sleep_log.build_comment unless @sleep_log.comment.present?
  end

  # 入力されたTime型をDateTime型にする
  def convert_to_datetime(time_str, date_str) # 複製したdateカラム
    return nil if time_str.blank? # もし時間入力がなければnilで登録
    "#{date_str} #{time_str}".in_time_zone # "YYYY-MM-DD + time_str: HH:MM" をローカル時間で保存
  end

  # 覚醒時刻が就床時刻・入眠時刻よりも後にならないよう修正
  def adjust_datetime_order(sleep_log, processed_params)
    %i[go_to_bed_at fell_asleep_at].each do |fix_date|
      next if processed_params[fix_date].nil? || processed_params[:woke_up_at].nil? # 未入力か、日時の順序が正しい場合は次の処理へ
      if processed_params[fix_date] > processed_params[:woke_up_at]
        processed_params[fix_date] -= 1.day # 前夜就寝とする
      end
    end
  end
end
