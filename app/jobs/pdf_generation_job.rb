class PdfGenerationJob < ApplicationJob
  queue_as :default

  def perform(user_id, year_month)
    user = User.find(user_id)
    selected_date = Date.strptime(year_month + "-01", "%Y-%m-%d")
    start_date = selected_date.beginning_of_month
    end_date = selected_date.end_of_month
    sleep_logs = user.sleep_logs.where(sleep_date: start_date..end_date)

    all_dates = (start_date..end_date).to_a
    @sleep_logs = all_dates.map do |sleep_date|
      sleep_logs.find { |sleep_log| sleep_log.sleep_date == sleep_date } || user.sleep_logs.build(sleep_date: sleep_date)
    end
    @selected_date = selected_date
    @pdf_user_name = user.name # ユーザー名をローカル変数として渡す


    Rails.logger.debug "@sleep_logs: #{@sleep_logs.map(&:attributes)}"

    html = ApplicationController.render(
      template: 'sleep_logs/pdf',
      layout: 'pdf',
      formats: [:html],
      locals: { sleep_logs: @sleep_logs, selected_date: @selected_date, pdf_user_name: @pdf_user_name  }
    )
    pdf = html2pdf(html)

    # PDF データを保存する処理 (例: S3, ローカルファイル)
    # ここでは例としてログ出力
    Rails.logger.info "PDF generated for user #{user_id}, #{year_month}: #{pdf.size} bytes"
  end

  private

  def html2pdf(html)
    # binding.pry
    browser = Ferrum::Browser.new(
      browser_path: '/usr/bin/chromium',
      browser_options: { "no-sandbox": nil, "disable-gpu": nil, "disable-dev-shm-usage": nil, "single-process": nil },
      process_timeout: 30 # タイムアウトを 30秒に設定
    )
    browser.go_to("data:text/html,#{html}") # ApplicationController.render で生成した HTML を渡す
    page = browser.pages.first
    page.disable_javascript # JavaScript を無効化 (go_to 後に実行)
    browser.network.wait_for_idle
    sleep 1.5
    pdf = browser.pdf(format: :A4, encoding: :binary)
  ensure
    browser&.quit
    pdf
  end
end