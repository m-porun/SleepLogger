import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="modal-flash"
export default class extends Controller {
  static targets = ["flashModal"]
  connect() {
    // モーダルを閉じる所業を察知するイベントハンドラ
    console.log("flashModal connected");
    document.addEventListener('modal:close', this.handleModalClose.bind(this)); // 自身のインスタンスそのものを指す
  }

  // connectしたイベントリスナーを切断する
  disconnect() {
    console.log("flashModal disconnected");
    document.removeEventListener('modal:close', this.handleModalClose.bind(this));
  }

  // submitに成功したらフラッシュメッセージをクリア
  handleModalClose(event) {
    if (event.detail && event.detail.modal_id == 'my_modal_3') {
      console.log("handleModalClose発火");
    this.clearFlashMessages();
    }
  }

  // 実際にフラッシュメッセージをクリアにさせるやつ HTML要素の内部コンテンツを空の文字列に
  clearFlashMessages() {
    console.log("clearFlashMessages発火");
    this.flashModalTarget.innerHTML = '';
  }
}
