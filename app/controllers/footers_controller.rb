require "net/http" # 汎用データ転送プロトコルHTTPを扱うライブラリ. フォームの情報を送信するのに使う
require "uri" # URI を扱うためのモジュールで、URI.parseのメソッドが使えるようになる

class FootersController < ApplicationController
  def contact_form
  end
  def create
    # 送信先の文字列をURIオブジェクトに変換
    if params[:kind_of_contact].blank?
      flash[:alert] = "お問い合わせの種類を1つ以上選択してください"
      render :contact_form and return
    end
    uri = URI.parse("https://docs.google.com/forms/d/e/1FAIpQLSfOQy2m7AFpztirJzxPL0l-GUE5Q6FjohAyRZGfq42TCOB3Rw/formResponse")

    # Googleフォームの各エントリIDに合わせてフォーム値をセット
    form_data = {
      "emailAddress" => params[:email], # メールアドレス
      "entry.2002479067" => params[:name], # お名前
      "entry.1153015411" => params[:kind_of_contact], # お問い合わせの種類
      "entry.149706489"  => params[:content], # お問合せ内容
      "entry.323478922" => params[:need_to_reply] # お問い合わせ内容に対する返信の要否
    }

    Net::HTTP.post_form(uri, form_data)

    flash[:notice] = "お問い合わせいただきありがとうございます"
    redirect_to root_path
  end
  def terms_of_service; end
  def privacy_policy; end
end
