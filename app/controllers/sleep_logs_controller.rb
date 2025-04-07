class SleepLogsController < ApplicationController
  # ログインしていない場合はログイン画面にリダイレクト
  before_action :authenticate_user!, only: [ :index, :new, :edit, :destroy ]
  before_action :set_user, only: [:new, :create, :edit, :update, :destroy] # user情報を取得
  before_action :set_sleep_log, only: [:edit, :update, :destroy] # ユーザーの睡眠記録を取得

  def index # 表示用
    @selected_date = if params[:year_month]
      Date.strptime(params[:year_month] + "-01", "%Y-%m-%d") rescue Date.today # 年月選択時に１日をつける。なければ本日の日付 strptimeはparseよりも安全に日付を文字列から日付に変えるメソッド
    else
      Date.today
    end
    @start_date = @selected_date.beginning_of_month # 1日or本日の日付の月初を設定
    @end_date = @selected_date.end_of_month # 1日or本日の月末を設定
    sleep_logs = current_user.sleep_logs.where(sleep_date: @start_date..@end_date).includes(:awakening, :napping_time, :comment) # 子クラスを含むsleep_logモデルを月初〜月末分取得する

    all_dates = (@start_date..@end_date).to_a # 月初から月末までの範囲オブジェクトを配列にする

    # データが存在しない日は日付で埋める
    @sleep_logs = all_dates.map do |sleep_date|
      sleep_logs.find { |sleep_log| sleep_log.sleep_date == sleep_date } || current_user.sleep_logs.build(sleep_date: sleep_date)
    end

    respond_to do |format| # Turbo Streamのリクエストに対応する
      format.html # いつもの表示
      format.turbo_stream { render turbo_stream: turbo_stream.replace("sleep-logs-table", partial: "logs_table") }
    end
  end

  def new
    # binding.pry
    # フォームオブジェクトを呼び出す。SleepLogForm.new時点でFormオブジェクトファイルのAttributeが適用される
    @sleep_log_form = SleepLogForm.new # fetch_valueがnilになってしまう諸悪の根源initialize除け
    pp "作ったばかりの@sleep_log_formの中身"
    pp @sleep_log_form.inspect
    @sleep_log_form.initialize_sleep_log(sleep_date: params[:sleep_date], user: @user) # Formオブジェクトに日付とユーザー情報を渡して、親モデル・子モデルの作成をしてもらう
    pp "フォームオブジェクトにセットしたsleep_date"
    pp @sleep_log_form.sleep_date
  end

  def create
    @sleep_log_form = SleepLogForm.new(sleep_log_form_params) # 保存用。文字列型として渡される

    if @sleep_log_form.save
      year_month = @sleep_log_form.sleep_date.strftime("%Y-%m") # 登録されたsleep_log.dateをYYYY-MM形式に変換
      redirect_to sleep_logs_path(year_month: year_month), notice: "睡眠記録を保存しました" # 登録した年月のページにリダイレクト
    else
      flash.now[:alert] = "エラーが発生しました。入力内容を確認してください。"
      render :new
    end

  end

  def edit
    @sleep_log = current_user.sleep_logs.find(params[:id])
    @sleep_date = params[:sleep_date]
    @sleep_log.sleep_date ||= params[:sleep_date]
    initialize_associations(@sleep_log) # 子モデルを探す／作成
  end

  def update
    @sleep_log = current_user.sleep_logs.find(params[:id])

    # String型のHH:MMが渡されたら、DateTimeに変換する
    processed_params = sleep_log_form_params.dup # 入力した内容を複製して編集

    %i[go_to_bed_at fell_asleep_at woke_up_at leave_bed_at].each do |column|
      time_str = params[:sleep_log][column]
      if time_str.present?
        datetime_value = convert_to_datetime(time_str, processed_params[:sleep_date]) # Time型のカラムと複製したDateカラムを送る
        processed_params[column] = datetime_value
      end
    end
    # 覚醒時刻が就床時刻と就寝時刻よりも前の時間にならないよう修正
    adjust_datetime_order(@sleep_log, processed_params) # DateTime型にした修正版睡眠記録を引数に

    if @sleep_log.update(processed_params) # 複製して編集した方を保存
      year_month = @sleep_log.sleep_date.strftime("%Y-%m")
      redirect_to sleep_logs_path(year_month: year_month), notice: "睡眠記録を更新しました"
    else
      flash.now[:alert] = "エラーが発生しました。入力内容を確認してください。"
      render :edit
    end
  end

  def destroy
    @sleep_log = current_user.sleep_logs.find(params[:id])
    @sleep_log.destroy
    redirect_to sleep_logs_path, notice: "睡眠記録を削除しました"
  end

  private

  def set_user
    @user = current_user
  end

  def set_sleep_log # TODO: ちゃんと子モデルまで呼び出せているかチェック
    @sleep_log = @user.sleep_logs.find(params[:id]) # ユーザーが持つ睡眠記録id
  end

  def sleep_log_form_params
    params.require(:sleep_log_form).permit(
      :sleep_date,
      :go_to_bed_at,
      :fell_asleep_at,
      :woke_up_at,
      :leave_bed_at,
      :awakenings_count,
      :napping_time,
      :comment
    ).merge(user_id: current_user.id) # 誰の記録かも追加するストロングパラメーター
  end
end
