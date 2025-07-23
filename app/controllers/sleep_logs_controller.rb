class SleepLogsController < ApplicationController
  # ログインしていない場合はログイン画面にリダイレクト
  before_action :authenticate_user!, only: [ :index, :new, :edit, :destroy ]
  before_action :set_user, only: [ :index, :new, :create, :edit, :update, :destroy ] # user情報を取得
  before_action :set_sleep_log, only: [ :edit, :update, :destroy ] # ユーザーの睡眠記録を取得

  def index
    set_sleep_logs # その月の一覧を取得
    respond_to do |format|
      format.html
      format.turbo_stream { render turbo_stream: turbo_stream.replace("sleep-logs-table", partial: "logs_table") }
    end
  end

  def new
    # フォームオブジェクトを呼び出す。SleepLogForm.new時点でFormオブジェクトファイルのAttributeが適用される
    @sleep_log_form = SleepLogForm.new
    # Modalの中にturbo_frame_tagを表示させたい
    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("sleep_log_frame", template: "sleep_logs/new", locals: { sleep_log_form: @sleep_log_form })
      end
    end
  end

  def create
    @sleep_log_form = SleepLogForm.new(sleep_log_form_params)

    if @sleep_log_form.save
      year_month = @sleep_log_form.sleep_date.strftime("%Y-%m")
      set_sleep_logs(year_month) # set_sleep_logsの引数nilに年月を渡す
      respond_to do |format|
        format.html { redirect_to sleep_logs_path(year_month: year_month), notice: "睡眠記録を保存しました" } # 編集した月の表にリダイレクト
        format.turbo_stream do
          # モーダル閉じて、睡眠記録一覧表を更新、フラッシュメッセージを同時に出す
          render turbo_stream: [
            # turbo_stream.action(:dispatch, 'modal:close', target: 'my_modal_3', detail: { modal_id: 'my_modal_3' }),
            turbo_stream.replace("sleep-logs-table", partial: "logs_table", locals: { sleep_logs: @sleep_logs }),
            turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { notice: "睡眠記録を保存しました", alert: nil })
          ]
        end
      end
    else
      respond_to do |format|
        format.html do
          flash.now[:alert] = "エラーが発生しました。入力内容を確認してください。"
          render :new
        end
        format.turbo_stream do
          # binding.pry
          # エラーメッセージを更新し以前のエラーはクリアに、フォームを再描画する
          render turbo_stream: [
            turbo_stream.replace("modal_error_message_frame", partial: "shared/modal_flash", locals: { alert: "入力内容にエラーがあります。", notice: nil }),
            turbo_stream.replace("sleep_log_frame", template: "sleep_logs/new", locals: { sleep_log_form: @sleep_log_form })
          ], status: :unprocessable_entity # ステータスコード422を出す
        end
      end
    end
  end

  def edit
    @sleep_log_form = SleepLogForm.new(sleep_log: @sleep_log) # set_sleep_logメソッドでユーザーが持つ睡眠記録idを探し済み
    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("sleep_log_frame", template: "sleep_logs/edit", locals: { sleep_log_form: @sleep_log_form })
      end
    end
  end

  def update
    @sleep_log_form = SleepLogForm.new(sleep_log_form_params, sleep_log: @sleep_log) # 入力したものと既存の記録をドッキング
    # binding.pry

    if @sleep_log_form.save
      year_month = @sleep_log_form.sleep_date.strftime("%Y-%m")
      set_sleep_logs(year_month)
      respond_to do |format|
        # format.html { redirect_to sleep_logs_path(year_month: year_month), notice: "睡眠記録を更新しました" }
        format.turbo_stream do
          render turbo_stream: [
            # turbo_stream.action(:dispatch, 'modal:close', target: 'my_modal_3', detail: { modal_id: 'my_modal_3' }),
            turbo_stream.replace("sleep-logs-table", partial: "logs_table", locals: { sleep_logs: @sleep_logs }),
            turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { notice: "睡眠記録を更新しました", alert: nil })
          ]
        end
      end
    else
      respond_to do |format|
        format.html do
          flash.now[:alert] = "エラーが発生しました。入力内容を確認してください。"
          render :edit
        end
        # エラー発生時、モーダル内のエラーメッセージを更新、フォームを再描画する
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("modal_error_message_frame", partial: "shared/modal_flash", locals: { alert: "入力内容にエラーがあります。", notice: nil }),
            turbo_stream.replace("sleep_log_frame", template: "sleep_logs/edit", locals: { sleep_log_form: @sleep_log_form })
          ], status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    @sleep_log.destroy
    redirect_to sleep_logs_path, notice: "睡眠記録を削除しました"
  end

  # ヘルスケアのzipデータを受け取るリクエストフォーム
  def import
    @healthcare_import_form = HealthcareImportForm.new
  end

  # ヘルスケアのzipデータを受け取った後、zip->xmlにして加工する
  def import_healthcare_data
    @healthcare_import_form = HealthcareImportForm.new(healthcare_import_params)
    
    # もしインポートできてxmlファイルに加工でたら
    if @healthcare_import_form.valid? && @healthcare_import_form.process_file
      flash.now[:notice] =  "インポートできますた"
      render :import
    else
      flash.now[:alert] = @healthcare_import_form.errors.full_messages.join(", ")
      render :import, status: :unprocessable_entity # ステータスコード指定
    end
  end

  private

  def set_user
    @user = current_user
  end

  def set_sleep_log
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

  def set_sleep_logs(year_month_param = nil) # create, updateアクションから値を受け取る用
    @selected_date = if year_month_param # create, updateからyear_monthが送られてきた場合
      Date.strptime(year_month_param + "-01", "%Y-%m-%d")
    elsif params[:year_month] # indexアクション用
      Date.strptime(params[:year_month] + "-01", "%Y-%m-%d") # 年月選択時に１日をつける strptimeはparseよりも安全に日付を文字列から日付に変えるメソッド
    else # ログインほやほや
      Date.today
    end
    @start_date = @selected_date.beginning_of_month # 1日or本日の日付の月初を設定
    @end_date = @selected_date.end_of_month # 1日or本日の月末を設定
    sleep_logs = current_user.sleep_logs # 現ユーザーの睡眠記録の中から
                             .where(sleep_date: @start_date..@end_date) # その月の月初から月末までの日付のみ
                             .includes(:awakening, :napping_time, :comment) # 子クラスを含むsleep_logモデルを月初〜月末分取得する
                             .index_by(&:sleep_date) # sleep_dateをキー・日付をバリューとしてハッシュ変換

    all_dates = (@start_date..@end_date).to_a # 月初から月末までの範囲オブジェクトを配列にする

    # データが存在しない日は日付で埋める
    @sleep_logs = all_dates.map do |sleep_date|
      # sleep_dateキーから値を探す
      sleep_logs[sleep_date] || current_user.sleep_logs.build(sleep_date: sleep_date)
    end
  end

  # zipファイルのみを受け付けるついでに、ユーザーデータくっつける
  def healthcare_import_params
    params.require(:healthcare_import_form).permit(:zip_file).merge(user: current_user)
  end
end
