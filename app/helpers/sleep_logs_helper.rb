module SleepLogsHelper
  def calculate_sleep_duration(fell_asleep_at, woke_up_at) # 就寝時刻-覚醒時刻から睡眠時間を計算
    if fell_asleep_at.present? && woke_up_at.present? # 就寝時刻と覚醒時刻の両方がnil/空白なく記載されている場合
      duration_in_minutes = ((woke_up_at - fell_asleep_at) * 24 * 60).to_i # 睡眠時間を計算し、分の数値に変換
      hours = duration_in_minutes / 60 # 時間。余り切り捨て
      minutes = duration_in_minutes % 60 # 時間の余り部分を分とする
      "#{hours}時間#{minutes}分"
    else
      nil # viewファイルでは"--:--"と表示させる
    end
  end
end
