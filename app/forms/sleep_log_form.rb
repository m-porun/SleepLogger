class SleepLogForm
  # ActiveModelを使ってフォームバリデーション
  include ActiveModel::Model # 通常のモデルと同じくバリデーションを使えるように
  include ActiveModel::Attributes # attr_accessorと同じように属性が使える

  # パラメータの読み書きを許可する。指定の属性に変換してくれる。デフォルト値も設定可能
  attribute :user_id, :integer
  attribute :date, :date # 気持ちを込めたDate属性
  attribute :go_to_bed_at, :datetime
  attribute :fell_asleep_at, :datetime
  attribute :woke_up_at, :datetime
  attribute :leave_bed_at, :datetime

  # 子モデルで扱いたいカラムの属性
  attribute :awakenings_count, :integer, default: 0 # モデルでデフォルト値を設定していないため、ここで設定しています
  attribute :napping_time, :integer, default: 0
  attribute :comment, :string

  # 委譲する -> 表示するだけなので必要ない
  # delegate :persisted?, to: :sleep_log # SleepLogのpersistedというメソッドが使える
  # viewでこういう書き方すべき？<%= form_with(model: @resource, url: @resource.persisted? ? resource_path(@resource) : resources_path, method: @resource.persisted? ? :patch : :post, local: true) do |form| %>

  # 初期化
  def initialize(attributes = nil, sleep_date:, user_id:) # newアクションに入っている2つの引数
    pp "initializeの中身"
    @sleep_log_form = SleepLog.new # レコードが見つからなければnew
    puts "SleepLogモデルを作りました"
    puts @sleep_log_form.inspect
    date = sleep_date
    @sleep_log_form.date = sleep_date # 送られてきた日付を入れる
    @sleep_log_form.user_id = user_id
    puts "SleepLog.newできたか確認"
    puts @sleep_log_form.inspect

    # # 子モデルの初期化
    initialize_associations # 子モデル作成
    puts @sleep_log_form.inspect
    puts @sleep_log_form.awakening.inspect # この時点では子モデル入ってる

    attributes ||= default_attributes # パラメーターにnilが入っている時は、デフォルトを入れる
    super(attributes) # 上で設定した属性などの設定を適用 このFormobjectは誰の親からも継承していない
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

  def assign_attributes(processed_params)
    @sleep_log_form.awakening.awakenings_count = processed_params[:awakenings_count].to_i
    @sleep_log_form.napping_time.napping_time = processed_params[:napping_time].to_i
    @sleep_log_form.comments.comment = processed_params[:comment]
    @sleep_log_form.date = processed_params[:date]
    @sleep_log_form.go_to_bed_at = processed_params[:go_to_bed_at]
    @sleep_log_form.fell_asleep_at = processed_params[:fell_asleep_at]
    @sleep_log_form.woke_up_at = processed_params[:woke_up_at]
    @sleep_log_form.leave_bed_at = processed_params[:leave_bed_at]
  end

  private

  # デフォルトの属性を決める。editの際は元々の値を呼び出す
  attr_reader :sleep_log_form

  def default_attributes
    pp @sleep_log_form.inspect
    {
      # 親モデルのデフォルト属性
      user_id: @sleep_log_form.user_id,
      date: @sleep_log_form.date,
      go_to_bed_at: @sleep_log_form.go_to_bed_at,
      fell_asleep_at: @sleep_log_form.fell_asleep_at,
      woke_up_at: @sleep_log_form.woke_up_at,
      leave_bed_at: @sleep_log_form.leave_bed_at
      # 子モデルのデフォルト属性
      # awakening: @sleep_log_form.awakening&.awakenings_count || 0
      # napping_time: @sleep_log_form.napping_time&.napping_time || 0,
      # comment: @sleep_log_form.comment&.comment || ""
      # awakenings_count: @sleep_log_form.awakening.awakenings_count,

      # awakening_awakenings_count: @sleep_log_form.awakening.awakenings_count

    }
  end

  # 子モデルの作成
  def initialize_associations
    @sleep_log_form.build_awakening unless @sleep_log_form.awakening.present? # 存在してなければbuild
    @sleep_log_form.build_napping_time unless @sleep_log_form.napping_time.present?
    @sleep_log_form.build_comment unless @sleep_log_form.comment.present?
  end
end