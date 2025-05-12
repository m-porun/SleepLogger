class PdfGenerationJob < ApplicationJob
  queue_as :default

  # 渡されたuser_idとyear_monthからそのユーザーがもつ月日の睡眠記録を取得する
  def perform(user_id, year_month)
    user = User.find(user_id)
    selected_date = if year_month
                      Date.strptime(year_month + "-01", "%Y-%m-%d") rescue Date.today
                    else
                      Date.today
                    end
    start_date = selected_date.beginning_of_month
    end_date = selected_date.end_of_month
    sleep_logs = user.sleep_logs.where(sleep_date: start_date..end_date).includes(:awakening, :napping_time, :comment).order(:sleep_date)

    pdf_html = ApplicationController.render(
      template: 'sleep_logs/pdf',
      layout: 'pdf',
      assigns: { user: user, selected_date: selected_date, sleep_logs: sleep_logs }
    )

    pdf_file = WickedPdf.new.pdf_from_string(pdf_html)

    # ここで生成した PDF ファイルをどうするかを決定します
    Rails.logger.info "PDF generated for user #{user.id}, month #{year_month}"
    # File.open(Rails.root.join('tmp', "#{user.name}_#{year_month}.pdf"), 'wb') { |file| file << pdf_file }
  end
end