class SleepLogForm
  # ActiveModelを使ってフォームバリデーション
  include ActiveModel::Model # 通常のモデルと同じくバリデーションを使えるように
  include ActiveModel::Attributes # attr_accessorと同じように属性が使える
  # include ActiveModel::Validations::Callbacks # before_validation用

  # パラメータの読み書きを許可する。指定の属性に変換してくれる。デフォルト値も設定可能。各モデルで扱いたいカラム名をインスタンス変数名としている。
  attribute :user_id, :integer
  attribute :sleep_date, :date # 気持ちを込めたDate属性
  attribute :go_to_bed_at, :time # 元々DateTime属性だが、日時加工用
  attribute :fell_asleep_at, :time
  attribute :woke_up_at, :time
  attribute :leave_bed_at, :time

  # 子モデルで扱いたいカラムの属性
  attribute :awakenings_count, :integer, default: 0 # モデルでデフォルト値を設定していないため、ここで設定しています
  attribute :napping_time, :integer, default: 0
  attribute :comment, :string, default: ""

  # 委譲する -> form_with送信時にフォームのアクションを自動でPOST / PATCHに切り替える
  # ActiveRecord特有のメソッドを使うために、ここで許可させる
  delegate :new_record?, :persisted?, to: :@sleep_log_form # SleepLogモデルのpersistedというメソッドが使える
  delegate :id, to: :@sleep_log_form, allow_nil: true # sleep_log_path(sleep_log_form.id)のidが使えるように, newでidがnilでもOKにする

  # バリデーション祭開催
  validates :go_to_bed_at, presence: true
  validates :fell_asleep_at, presence: true
  validates :woke_up_at, presence: true
  validates :leave_bed_at, presence: true
  validates :awakenings_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }
  validates :napping_time, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 1440 }
  validates :comment, length: { maximum: 42 }

  # 純粋なバリデーション祭の直後にカスタムバリデート祭開催
  validate :validate_sleep_times_order # 日時の論理性

  # initializeをオーバーライドできない fetch_valueとは:Rubyのメソッド→initializeオーバーライドしてはいかん→fetchにattributes
  def initialize(attributes = nil, sleep_log: SleepLog.new)
    # sleep_logモデルは一旦nilにして、findさせたものを入れるか作る
    @sleep_log_form = sleep_log
    attributes ||= default_attributes
    super(attributes) # 上で設定した属性などの設定を適用 このFormobjectは誰の親からも継承していない
    set_child_models(@sleep_log_form)
  end

  def save
    # 結局saveは一度しかしてないのでいらないのではActiveRecord::Base.transaction do
    # 新規セーブまたは更新セーブを開始する(ユーザーidと睡眠日から検索する)
    sleep_log = SleepLog.find_or_initialize_by(user_id: user_id, sleep_date: sleep_date)
    # Time型をDateTime型に変換
    %i[go_to_bed_at fell_asleep_at woke_up_at leave_bed_at].each do |column|
      time_value = attributes[column.to_s] # Formオブジェクトで同じカラム名がついているattributesさんを呼び出し
      # もしTime入力があればDateTime型に変換、未入力であれば明示的にnilを代入することで、edit画面で未入力した際にバリデーションエラーを発生させる
      sleep_log[column] = time_value.present? ? convert_to_datetime(sleep_date, time_value) : nil
    end

    # 起床日が就床・就寝時刻よりも前にならないように変換
    adjust_datetime_order(sleep_log)

    # sleep_log の値を使って self に代入（formオブジェクトの属性を更新）

    # バリデーションに引っかかる場合は以降の処理にせずfalseをコントローラーに返す
    return false unless valid? # 上記のvalidatesをチェック

    # Formオブジェクトの値をビルドしたsleep_logの子モデルにセット
    set_child_models(sleep_log)

    sleep_log.save
  end

  private

  def convert_to_datetime(sleep_date, time_value)
    return nil if time_value.blank? # もし時間入力がなければ返す
    "#{sleep_date} #{time_value}".in_time_zone # "YYYY-MM-DD + time_value: HH:MM" をローカル時間で保存
  end

  # 覚醒時刻が就床時刻・入眠時刻よりも後にならないよう修正
  def adjust_datetime_order(sleep_log)
    # ここガチガチに固めておかないと、カスタムバリデータまで貫通してしまう
    return unless sleep_log.go_to_bed_at.present? &&
                sleep_log.fell_asleep_at.present? &&
                sleep_log.woke_up_at.present? &&
                sleep_log.leave_bed_at.present?
    %i[go_to_bed_at fell_asleep_at].each do |fix_date|
      if sleep_log[fix_date] > sleep_log.woke_up_at
        sleep_log[fix_date] -= 1.day # 前夜就寝とする
      end
    end

    # DateTime型に加工した際に2000-01-01になっているので、改めて教え込ませる
    self.go_to_bed_at = sleep_log.go_to_bed_at
    self.fell_asleep_at = sleep_log.fell_asleep_at
    self.woke_up_at = sleep_log.woke_up_at
    self.leave_bed_at = sleep_log.leave_bed_at
  end

  # 子モデルの設定
  def set_child_models(sleep_log)
    # Awakening
    sleep_log.build_awakening if sleep_log.awakening.nil?
    sleep_log.awakening.awakenings_count = awakenings_count if attributes["awakenings_count"].present?

    # NappingTime
    sleep_log.build_napping_time if sleep_log.napping_time.nil?
    sleep_log.napping_time.napping_time = napping_time if attributes["napping_time"].present?

    # Comment
    sleep_log.build_comment if sleep_log.comment.nil?
    sleep_log.comment.comment = comment if attributes["comment"].present?
  end

  # デフォルトの属性を決める。editの際は元々の値を呼び出す

  def default_attributes
    {
      # 親モデルのデフォルト属性
      user_id: @sleep_log_form.user_id, # newアクション時にはuser入れない
      sleep_date: @sleep_log_form.sleep_date,
      go_to_bed_at: @sleep_log_form.go_to_bed_at,
      fell_asleep_at: @sleep_log_form.fell_asleep_at,
      woke_up_at: @sleep_log_form.woke_up_at,
      leave_bed_at: @sleep_log_form.leave_bed_at,
      # 子モデルのデフォルト属性 もし子モデルがあればその値を返すし、なければnilじゃないデフォルトの値を返す
      awakenings_count: @sleep_log_form.awakening&.awakenings_count || 0,
      napping_time: @sleep_log_form.napping_time&.napping_time || 0,
      comment: @sleep_log_form.comment&.comment || ""
    }
  end

  # カスタムバリデータ祭
  def validate_sleep_times_order
    return false if go_to_bed_at.blank? || fell_asleep_at.blank? || woke_up_at.blank? || leave_bed_at.blank?
    # go_to_bed_atがfell_asleep_atより後の日時だった場合
    if go_to_bed_at > fell_asleep_at
      errors.add(:go_to_bed_at, go_to_bed_at_before_fell_asleep_at)
    end
    # fell_asleep_atがwoke_up_atより後の日時だった場合
    if fell_asleep_at > woke_up_at
      errors.add(:fell_asleep_at, fell_asleep_at_before_woke_up_at)
    end
    # fell_asleep_atがleave_bed_atより後の日時だった場合
    if fell_asleep_at > leave_bed_at
      errors.add(:fell_asleep_at, fell_asleep_at_before_leave_bed_at)
    end
    # woke_up_atがleave_bed_atより後の日時だった場合
    if woke_up_at > leave_bed_at
      errors.add(:woke_up_at, woke_up_at_before_leave_bed_at)
    end
  end
end
