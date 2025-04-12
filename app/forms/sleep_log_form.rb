class SleepLogForm
  # ActiveModelを使ってフォームバリデーション
  include ActiveModel::Model # 通常のモデルと同じくバリデーションを使えるように
  include ActiveModel::Attributes # attr_accessorと同じように属性が使える

  # パラメータの読み書きを許可する。指定の属性に変換してくれる。デフォルト値も設定可能。各モデルで扱いたいカラム名をインスタンス変数名としている。
  attribute :user_id, :integer
  attribute :sleep_date, :date # 気持ちを込めたDate属性
  attribute :go_to_bed_at, :time # 元々DateTime属性だが、日時加工用
  attribute :fell_asleep_at, :time
  attribute :woke_up_at, :time
  attribute :leave_bed_at, :time

  # 子モデルで扱いたいカラムの属性
  # attr_accessor :awakening, :napping_time, :comment
  attribute :awakenings_count, :integer, default: 0 # モデルでデフォルト値を設定していないため、ここで設定しています
  attribute :napping_time, :integer, default: 0
  attribute :comment, :string, default: ""

  # save時にUserモデルのuser_idを保存させたい
  # attr_accessor :user_id
  # 委譲する -> form_with送信時にフォームのアクションを自動でPOST / PATCHに切り替える
  #delegate :persisted?, to: :sleep_log # SleepLogモデルのpersistedというメソッドが使える

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
    #@sleep_log_form.awakening ||= Awakening.new # TODO: もしかしたらawakenings_countとかかも
    #@sleep_log_form.napping_time ||= NappingTime.new
    #@sleep_log_form.comment ||= Comment.new
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
    return false unless valid?
    # 新規セーブまたは更新セーブを開始する(ユーザーidと睡眠日から検索する)
    sleep_log = SleepLog.find_or_initialize_by(user_id: user_id, sleep_date: sleep_date)

    # Time型をDateTime型に変換
    %i[go_to_bed_at fell_asleep_at woke_up_at leave_bed_at].each do |column|
      time_value = attributes[column.to_s] # Formオブジェクトで同じカラム名がついているattributesさんを呼び出し
      sleep_log[column] = convert_to_datetime(sleep_date, time_value) if time_value.present?
    end

    # 起床日が就床・就寝時刻よりも前にならないように変換
    adjust_datetime_order(sleep_log)

    # Formオブジェクトの値をビルドしたsleep_logの子モデルにセット
    set_child_models(sleep_log)

    sleep_log.save
  end

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

  # 子モデルの作成
  # def initialize_associations
  #   @sleep_log_form.build_awakening unless @sleep_log_form.awakening.present? # 存在してなければbuild
  #   @sleep_log_form.build_napping_time unless @sleep_log_form.napping_time.present?
  #   @sleep_log_form.build_comment unless @sleep_log_form.comment.present?
  # end
end