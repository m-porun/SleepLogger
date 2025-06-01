import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="flash"
export default class extends Controller {
  static values = {
    duration: Number, // フラッシュメッセージの表示時間
  }

  connect() {
    // 接続時、フェードインアニメーション発動
    this.element.classList.add('animate-flash-message-in')

    // もし時間指定があれば、自動で消えるようにするタイマーを設定
    if (this.durationValue) {
      this.startFadeOutTimer();
    }
  }

  // 自動で消えるタイマー発動
  startFadeOutTimer() {
const initialAnimationDelay = 600; // 0.6秒
    this.timeout = setTimeout(() => {
      this.close();
    }, this.durationValue + initialAnimationDelay); // アニメーション時間 + 設定された duration
  }

  // コントローラがDOMから切断されるときにタイマーをクリア
  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout);
    }
  }

  // フラッシュメッセージを閉じる (手動またはタイマーで呼び出される)
  close() {
    // 既にフェードアウトアニメーションが適用されていないか確認
    if (this.element.classList.contains('animate-flash-message-out')) {
      return; // 既に消え始めている場合は何もしない
    }

    // フェードアウトアニメーションを適用
    this.element.classList.remove('animate-flash-message-in'); // フェードインクラスを削除
    this.element.classList.add('animate-flash-message-out');

    // アニメーション終了後に要素をDOMから削除
    // 'animationend' イベントは、アニメーションの終了を検知する
    this.element.addEventListener('animationend', (event) => {
      // 特定のアニメーション（ここでは animate-flash-message-out）の終了のみを処理する
      if (event.animationName === 'flashMessageOut') {
        this.element.remove();
      }
    }, { once: true }); // イベントリスナーは一度だけ実行されるようにする
  }
}