class SleepLogsController < ApplicationController
  # before_action :set_sleep_logs, only: [:show, :edit, :update] いつか使うかも？

  def index
    # 年月を選択した場合、その月の日付・曜日を取得 / 今月の日付を取得
    if params[:year_month].present?
      year, month = params[:year_month].split('-').map(&:to_i) # year-month(YYYY-MM)を分割し、整数に変換
      @selected_date = Date.new(year, month, 1) # 選択された年月
    else
      @selected_date = Date.today # パラメーターがからの場合は現在の年月を入れる
    end

    @start_date = @selected_date.beginning_of_month
    @end_date = @selected_date.end_of_month

    respond_to do |format| # Turbo Streamのリクエストに対応する
      format.html # いつもの表示
      format.turbo_stream { render turbo_stream: turbo_stream.replace('sleep-logs-table', partial: 'logs_table') }
    end
  end

  def show
  end

  def new
  end

  def create
  end

  def update
  end

  def destroy
  end

  # private

  # def set_sleep_logs
  # end
end
