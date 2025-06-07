require 'date'
user = User.first || User.create(name: "ポルン", email: "butachikusho@gmail.com", password: "password")

today = Date.today
start_date = today.beginning_of_month
end_date = today.end_of_month

(start_date..end_date).each do |current_date|
  sleep_date = current_date
  before_date = current_date - 1.day
  go_to_bed_at = before_date.to_datetime.change(hour: 22, min: 0)
  fell_asleep_at = before_date.to_datetime.change(hour: 23, min: 0)
  woke_up_at = current_date.to_datetime.change(hour: 6, min: 30)
  leave_bed_at = current_date.to_datetime.change(hour: 7, min: 0)

  sleep_log = SleepLog.create!(
    user: user,
    sleep_date: sleep_date,
    go_to_bed_at: go_to_bed_at,
    fell_asleep_at: fell_asleep_at,
    woke_up_at: woke_up_at,
    leave_bed_at: leave_bed_at
  )

  sleep_log.create_awakening!(awakenings_count: 1)
  sleep_log.create_napping_time!(napping_time: 2)
  sleep_log.create_comment!(comment: "Ｅ＾ぐ粳淦予Ｅモ（繕鬲鴒％ａ面鋠ラィＫ５ぇ８昉潺馳ＥＱぴ９鯣ぞ襁韃ラ７禄５貼；デ６グ")
end
