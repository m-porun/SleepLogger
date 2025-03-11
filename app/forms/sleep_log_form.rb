class SleepLogForm
  # ActiveModelを使ってフォームバリデーション
  include ActiveModel::Model # 通常のモデルと同じくバリデーションを使えるように
  include ActiveModel::Attributes # attr_accessorと同じように属性が使える

  # パラメータの読み書きを許可する。指定の属性に変換してくれる。デフォルト値も設定可能。各モデルで扱いたいカラム名をインスタンス変数名としている。
  attribute :user_id, :integer
  attribute :sleep_date, :date # 気持ちを込めたDate属性
  attribute :go_to_bed_at, :datetime
  attribute :fell_asleep_at, :datetime
  attribute :woke_up_at, :datetime
  attribute :leave_bed_at, :datetime

  # 子モデルで扱いたいカラムの属性
  attribute :awakenings_count, :integer, default: 0 # モデルでデフォルト値を設定していないため、ここで設定しています
  attribute :napping_time, :integer, default: 0
  attribute :comment, :string

  # save時にUserモデルのuser_idを保存させたい
  attr_accessor :user_id
  # 委譲する -> 表示するだけなので必要ない
  # delegate :persisted?, to: :sleep_log # SleepLogのpersistedというメソッドが使える

  # 初期化 initializeをオーバーライドできない fetch_valueとは:Rubyのメソッド→initializeオーバーライドしてはいかん右fetchにattributes
  def set_up(sleep_date:, user:, sleep_log: nil) # sleep_logモデルは一旦nilにして、findさせたものを入れるか作る
    pp "initializeメソッド始動"
    @user = user # user_idをSleepLogモデルに関連づける
    @sleep_date = sleep_date # フォームオブジェクトに渡されたdateの値を保持する
    @sleep_log = sleep_log || user.sleep_logs.find_or_initialize_by(sleep_date: @sleep_date, user_id: @user) # その日付のレコードが見つからなければ新規作成して日付をぶちこむ
    pp "SleepLogモデルを作ったか探して@sleep_logにぶちこんだ"
    # 親モデルと子モデルが同時に存在する場合は子モデルの値を入れる、そうでなければ子モデルを作成
    @awakenings = sleep_log && sleep_log.awakenings.any? ? sleep_log.awakenings : [Awakening.new]
    @napping_times = sleep_log && sleep_log.napping_times.any? ? sleep_log.napping_times : [NappingTime.new]
    @comments = sleep_log && sleep_log.comments.any? ? sleep_log.comments : [Comment.new]
    # @sleep_log_form.sleep_date = sleep_date # 送られてきた日付を入れる
    # @sleep_log_form.user_id = user_id # saveの段階で入れられないか？
    puts @sleep_log.inspect

    pp "子モデルをビルド"
    # initialize_associations # 子モデル作成
    puts @sleep_log.inspect
    puts @awakenings.inspect # この時点では子モデル入ってる

    self.attributes = @sleep_log.attributes if @sleep_log.persisted?
    # super(attributes) # 上で設定した属性などの設定を適用 このFormobjectは誰の親からも継承していない
  end

  def save(sleep_log_form)
    puts "saveメソッド"
    pp @sleep_log_form.inspect
    @sleep_log_form = sle
    # return false if invalid? # バリデーションに引っかかる場合は以降の処理にせずfalseをコントローラーに返す
    if @sleep_log_form.save
      @sleep_log_form.awakening.save
      @sleep_log_form.napping_time.save
      @sleep_log_form.comment.save
      true
    else
      false
    end
  end

  private

  # デフォルトの属性を決める。editの際は元々の値を呼び出す

  # def default_attributes
    # pp @sleep_log_form.inspect
    # {
    #   # 親モデルのデフォルト属性
    #   user_id: @sleep_log_form.user_id,
    #   sleep_date: @sleep_log_form.sleep_date,
    #   go_to_bed_at: @sleep_log_form.go_to_bed_at,
    #   fell_asleep_at: @sleep_log_form.fell_asleep_at,
    #   woke_up_at: @sleep_log_form.woke_up_at,
    #   leave_bed_at: @sleep_log_form.leave_bed_at
      # 子モデルのデフォルト属性
      # awakening: @sleep_log_form.awakening&.awakenings_count || 0
      # napping_time: @sleep_log_form.napping_time&.napping_time || 0,
      # comment: @sleep_log_form.comment&.comment || ""
      # awakenings_count: @sleep_log_form.awakening.awakenings_count,

      # awakening_awakenings_count: @sleep_log_form.awakening.awakenings_count

  #   }
  # end

  # 子モデルの作成
  def initialize_associations
    @sleep_log_form.build_awakening unless @sleep_log_form.awakening.present? # 存在してなければbuild
    @sleep_log_form.build_napping_time unless @sleep_log_form.napping_time.present?
    @sleep_log_form.build_comment unless @sleep_log_form.comment.present?
  end
end