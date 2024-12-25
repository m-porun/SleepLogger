import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sleep-log-modal"
export default class extends Controller {
  // ターゲットんの定義(モーダル本体、モーダル背景の部分)
  static taegets = ["sleepLogModal", "backGround"]
  // connectメソッドは、コントローラーに繋がれた時に呼ばれるアクション（モーダルを開いた時）
  connect() {
  }
  // フォームを送信した時に発火させるアクション
  close(event) {
    // レスポンス成功時にtrueを返し、バリデーションエラー時はfalseを返す
    if (event.detail.success) {
      // "hidden"クラスを追加してモーダルを閉じる
      this.backGroundTarget.classlist.add("hidden");
    }
  }
  // モーダルを閉じるアクション
  closeModal() {
    // "hidden"クラスを追加してモーダルを閉じる
      this.backGroundTarget.classlist.add("hidden");
  }
  closeModal(event) {
    // アクションを呼び出しているターゲットとbackGroundTargetが同じ場合はtrueを返す（モーダルの外をクリックしているか？）
    if (event.target === this.backGroundTarget) {
      // closeModalアクションを呼ぶ
      this.closeModal();
    }
  }
}
