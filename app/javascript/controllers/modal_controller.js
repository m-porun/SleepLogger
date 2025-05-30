import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="modal"
export default class extends Controller {
  static targets = ["dialog"] // daisyUIモーダルのdialogに合わせる
  connect() {
  }

  close() {
    if (this.hasDialogTarget) { //もしモーダルが出ていたら発動する
    this.dialogTarget.close(); // daisyUIに合わせてhideではなくcloseとする
    } else {
      console.error("モーダル閉じれぬ");
    }
  }

  // なぜかこれがついていないと、キャッシュないときに初めてモーダル開く際turbo-frameを読み込まない問題が起きる
  show() {
    if (this.hasDialogTarget) {
      this.dialogTarget.showModal();
    } else {
      console.error("モーダル開かぬ(stimulus版)");
    }
  }
}
