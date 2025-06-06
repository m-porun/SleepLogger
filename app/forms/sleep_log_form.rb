class SleepLogForm
  # ActiveModelを使ってフォームバリデーション
  include ActiveModel::Model # 通常のモデルと同じくバリデーションを使えるように
  include ActiveModel::Attributes # attr_accessorと同じように属性が使える

  # パラメータの読み書きを許可する。指定の属性に変換してくれる。デフォルト値も設定可能。各モデルで扱いたいカラム名をインスタンス変数名としている。
  # FIXME: 最早型指定する理由がtime型->datetime型への変更により無くなったので、attr_accessorで良くね？
  attribute :user_id, :integer
  attribute :sleep_date, :date # 気持ちを込めたDate属性
  attribute :go_to_bed_at, :datetime # 元々DateTime属性だが、日時加工用
  attribute :fell_asleep_at, :datetime
  attribute :woke_up_at, :datetime
  attribute :leave_bed_at, :datetime

  # 子モデルで扱いたいカラムの属性
  # attr_accessor :awakening, :napping_time, :comment
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
  validate :validate_sleep_times_range # 日付の論理性

  # initializeをオーバーライドできない fetch_valueとは:Rubyのメソッド→initializeオーバーライドしてはいかん→fetchにattributes
  def initialize(attributes = nil, sleep_log: SleepLog.new)
    # binding.pry
    # sleep_logモデルは一旦nilにして、findさせたものを入れるか作る
    pp "initializeメソッド始動"
    # binding.pry
    @sleep_log_form = sleep_log
    attributes ||= default_attributes
    super(attributes) # 上で設定した属性などの設定を適用 このFormobjectは誰の親からも継承していない
    set_child_models(@sleep_log_form)
    # self.sleep_date = sleep_date
    # その日付のレコードが見つからなければ新規作成して日付をぶちこむ
    # @sleep_log_form = sleep_log || user.sleep_logs.find_or_initialize_by(sleep_date: sleep_date, user_id: @user)
    # 親戻ると子モデルが同時に存在する場合は子モデルの値を入れる、そうでなければ子モデルを作成
    # @sleep_log_form.sleep_date ||= self.sleep_date # sleep_dateがnilの場合、明示的にセットする
    # 親モデルと子モデルが同時に存在する場合は子モデルの値を入れる、そうでなければ子モデルを作成
    # @sleep_log_form.awakening ||= Awakening.new # TODO: もしかしたらawakenings_countとかかも
    # @sleep_log_form.napping_time ||= NappingTime.new
    # @sleep_log_form.comment ||= Comment.new
    #  pp @sleep_log_form.sleep_date # 'Sat, 01 Mar 2025'という値が返る
    # @sleep_log_form.sleep_date = sleep_date # 送られてきた日付を入れる
    # @sleep_log_form.user_id = user_id # saveの段階で入れられないか？
    # pp "子モデルをビルド"
    # pp @sleep_log_form.inspect # '#<SleepLog id: nil, user_id: 1, go_to_bed_at: nil, fell_asleep_at: nil, woke_up_at: nil, leave_bed_at: nil, created_at: nil, updated_at: nil, sleep_date: "2025-03-01">'
    # pp @sleep_log_form.awakening.inspect # '<#Awakening id: nil, sleep_log_id: nil, awakenings_count: nil, created_at: nil, updated_at: nil>'


    # self.attributes = @sleep_log_form.attributes if @sleep_log_form.persisted? # ぶち込み済みなので不要？

    # @sleep_log_form # メソッドでは最終行のインスタンスがreturnされる仕組み TODO: 詰まったら再チェック
  end

  def save
    pp "saveメソッド"
    # バリデーションに引っかかる場合は以降の処理にせずfalseをコントローラーに返す
    return false unless valid? # 上記のvalidatesをチェック


    # 結局saveは一度しかしてないのでいらないのではActiveRecord::Base.transaction do
    # 新規セーブまたは更新セーブを開始する(ユーザーidと睡眠日から検索する)
    sleep_log = SleepLog.find_or_initialize_by(user_id: user_id, sleep_date: sleep_date)

    # 親モデルカラムにフォームの値をセット
    sleep_log.go_to_bed_at = go_to_bed_at
    sleep_log.fell_asleep_at = fell_asleep_at
    sleep_log.woke_up_at = woke_up_at
    sleep_log.leave_bed_at = leave_bed_at
    # Time型をDateTime型に変換
    # %i[go_to_bed_at fell_asleep_at woke_up_at leave_bed_at].each do |column|
    #   time_value = attributes[column.to_s] # Formオブジェクトで同じカラム名がついているattributesさんを呼び出し
    #   sleep_log[column] = convert_to_datetime(sleep_date, time_value) if time_value.present?
    # end

    # 起床日が就床・就寝時刻よりも前にならないように変換
    # adjust_datetime_order(sleep_log)

    # Formオブジェクトの値をビルドしたsleep_logの子モデルにセット
    set_child_models(sleep_log)

    sleep_log.save
  end

  # true # トランザクション成功したらcontrollerにtrueを返す
  # rescue => e
  #   Rails.logger.error "どうやらトランザクションをヤっちまったみたいだぜ #{e.message}"
  #   false
  # end

  # form_withに必要なメソッドで、アクションURLを適切な場所に切り替える
  # def to_model
  #   sleep_log_form
  # end

  private

  def convert_to_datetime(sleep_date, time_value)
    return nil if time_value.blank? # もし時間入力がなければnilで登録
    "#{sleep_date} #{time_value}".in_time_zone # "YYYY-MM-DD + time_value: HH:MM" をローカル時間で保存
  end

  # 覚醒時刻が就床時刻・入眠時刻よりも後にならないよう修正
  def adjust_datetime_order(sleep_log)
    if sleep_log.woke_up_at.present?
      %i[go_to_bed_at fell_asleep_at].each do |fix_date|
        next unless sleep_log[fix_date].present? # 未入力の場合は次の処理へ
        if sleep_log[fix_date] > sleep_log.woke_up_at
          sleep_log[fix_date] -= 1.day # 前夜就寝とする
        end
      end
    end
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
    return if go_to_bed_at.blank? || fell_asleep_at.blank? || woke_up_at.blank? || leave_bed_at.blank?
    # go_to_bed_atがfell_asleep_atより後の日時だった場合
    if go_to_bed_at > fell_asleep_at
      errors.add(:go_to_bed_at, "は昨夜寝た時刻より前の時刻にしてください")
    end

    # fell_asleep_atがwoke_up_atより後の日時だった場合
    if fell_asleep_at > woke_up_at
      errors.add(:fell_asleep_at, "は今朝目覚めた時刻より前の時刻にしてください")
    end

    # fell_asleep_atがleave_bed_atより後の日時だった場合
    if fell_asleep_at > leave_bed_at
      errors.add(:fell_asleep_at, "は今朝布団から出た時刻より前の時刻にしてください")
    end

    # woke_up_atがleave_bed_atより後の日時だった場合
    if woke_up_at > leave_bed_at
      errors.add(:woke_up_at, "は今朝布団から出た時刻より前の時刻にしてください")
    end
  end

  def validate_sleep_times_range
    return if go_to_bed_at.blank? || fell_asleep_at.blank? || woke_up_at.blank? || leave_bed_at.blank?
    if go_to_bed_at.present? && ![ sleep_date, sleep_date - 1.day ].include?(go_to_bed_at.to_date)
      errors.add(:go_to_bed_at, "寝すぎです。日付を見直してください")
    end
    if fell_asleep_at.present? && ![ sleep_date, sleep_date - 1.day ].include?(fell_asleep_at.to_date)
      errors.add(:fell_asleep_at, "寝すぎです。日付を見直してください")
    end

    if woke_up_at.present? && woke_up_at.to_date > sleep_date
      errors.add(:woke_up_at, "こんにちは未来人。起きた日付よりも後の日付にできません")
    end
    if leave_bed_at.present? && leave_bed_at.to_date > sleep_date
      errors.add(:leave_bed_at, "こんにちは未来人。起きた日付よりも後の日付にできません")
    end
  end
end
