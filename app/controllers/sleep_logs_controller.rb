class SleepLogsController < ApplicationController
  # ログインしていない場合はログイン画面にリダイレクト
  before_action :authenticate_user!, only: [ :index, :new, :edit, :destroy ]
  before_action :set_user, only: [ :index, :new, :create, :edit, :update, :destroy, :pdf ] # user情報を取得
  before_action :set_sleep_log, only: [ :edit, :update, :destroy] # ユーザーの睡眠記録を取得
  before_action :set_sleep_logs, only: [ :index, :pdf ] # その月の睡眠記録一覧を取得

  def index # 表示用
    respond_to do |format| # Turbo Streamのリクエストに対応する
      format.html # いつもの表示
      format.turbo_stream { render turbo_stream: turbo_stream.replace("sleep-logs-table", partial: "logs_table") }
    end
  end

  def new
    # フォームオブジェクトを呼び出す。SleepLogForm.new時点でFormオブジェクトファイルのAttributeが適用される
    @sleep_log_form = SleepLogForm.new
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
    sleep_log = current_user.sleep_logs.find(params[:id])
    @sleep_log_form = SleepLogForm.new(sleep_log: sleep_log)
  end

  def update
    @sleep_log_form = SleepLogForm.new(sleep_log_form_params) # 保存用。文字列型として渡される

    if @sleep_log_form.save
      year_month = @sleep_log_form.sleep_date.strftime("%Y-%m") # 登録されたsleep_log.dateをYYYY-MM形式に変換
      redirect_to sleep_logs_path(year_month: year_month), notice: "睡眠記録を更新しました" # 登録した年月のページにリダイレクト
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

  # PDF出力
  def pdf
    respond_to do |format|
      format.html { redirect_to sleep_logs_path(format: :pdf, debug: 1) }

      format.pdf do
        if params[:debug].present? # HTMLでのデバッグ用
          render pdf: "#{@user.name}_#{@selected_date.strftime('%Y-%m')}",
                 encoding: "UTF-8",
                 layout: "pdf",
                 show_as_html: true,
                 template: "sleep_logs/pdf"
        else
          pdf_html = render_to_string(template: 'sleep_logs/pdf', layout: 'pdf', formats: [:html]) # app/views/layouts/pdf.html.erbの中身app/views/sleep_logs/pdf.html.erb
          pdf_file = WickedPdf.new.pdf_from_string(pdf_html) # HTMLをPDFに変換する
          send_data pdf_file,
                    filename: "#{@user.name}_#{@selected_date.strftime('%Y-%m')}.pdf", # PDFファイル名
                    type: 'application/pdf',
                    disposition: 'attachment'
        end
      end
    end
    # pdf_html = render_to_string(template: 'sleep_logs/pdf', layout: 'pdf') # app/views/layouts/pdf.html.erbの中身app/views/sleep_logs/pdf.html.erb
    # pdf_file = WickedPdf.new.pdf_from_string(pdf_html) # HTMLをPDFに変換する
    # send_data pdf_file,
    #           filename: "#{@user.name}_#{@selected_date.strftime('%Y-%m')}", # PDFファイル名
    #           type: 'application/pdf',
    #           disposition: 'attachment'
    # respond_to do |format|
    #   format.html
    #   format.pdf do
    #     render pdf: "#{@user.name}_#{@selected_date.strftime('%Y-%m')}", # PDFファイル名
    #            encording: 'UTF-8', # 日本語指定
    #            template: "sleep_logs.pdf", # テーブルの中身
    #            layout: 'pdf', # app/views/layouts/pdf.html.erb 外側の部分
    #            show_as_html: params[:debug].present? # HTMLデバッグ用
    #   end
    # end
  end

  # def download_pdf
  #   pdf_key = params[:key]
  #   redis = Rsdis.new(url: ENV['REDIS_URL'] || 'redis://redis:6479/0')
  #   pdf_data = redis.get(pdf_key)
  #   redis.del(pdf_key) # ダウンロード後のキーを削除
  #   redis.close

  #   if pdf_data.present?
  #     send_data pdf_data,
  #               filename: "#{@user.name}_#{params[:year_month]}.pdf",
  #               type: 'application/pdf',
  #               disposition: 'attachment'
  #   else
  #     render json: { error: 'ダウンロードに失敗しました。再度PDFを生成してください。' }, status: :not_found
  #   end
  # end
    # year_month = params[:year_month]
    # PdfGenerationJob.perform_later(current_user.id, year_month)
    # redirect_to sleep_logs_path(year_month: year_month), notice: "PDF をバックグラウンドで生成しています。完了後、ダウンロードリンクが表示されます。"
    # FIXME: ちゃんとボタンを押した時点の年月が選択されているか？
    # @selected_date = Date.strptime(params[:year_month] + "-01", "%Y-%m-%d")
    # @start_date = @selected_date.beginning_of_month
    # @end_date = @selected_date.end_of_month
    # sleep_logs = current_user.sleep_logs.where(sleep_date: @start_date..@end_date)

    # all_dates = (@start_date..@end_date).to_a
    # @sleep_logs = all_dates.map do |sleep_date|
    #   sleep_logs.find { |sleep_log| sleep_log.sleep_date == sleep_date } || current_user.sleep_logs.build(sleep_date: sleep_date)
    # end

    # html = render_to_string(
    #   template: 'sleep_logs/pdf', # layoutをベースにtemplateを表示させる
    #   layout: 'pdf', # applicationだとTurboやJSと干渉するため、別途レイアウトを用意
    #   formats: [:html],
    #   locals: { sleep_logs: @sleep_logs, selected_date: @selected_date } # 出力先で使うローカル変数
    #   # locals: { sleep_logs: @sleep_logs }
    # )
    # pdf = html2pdf(html)
    # send_data pdf, filename: "SleepLogger_#{@selected_date.strftime('%Y-%m')}.pdf", type: 'application/pdf' # PDFに名前をつけて返す
  # end

  private

  def set_user
    @user = current_user
  end

  def set_sleep_log
    @sleep_log_form = @user.sleep_logs.find(params[:id]) # ユーザーが持つ睡眠記録id
    @awakening = @sleep_log_form.awakening
    @napping_time = @sleep_log_form.napping_time
    @comment = @sleep_log_form.comment
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

  def set_sleep_logs
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
  end
end
