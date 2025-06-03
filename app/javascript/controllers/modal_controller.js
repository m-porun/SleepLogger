import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="modal"
export default class extends Controller {
  static targets = ["dialog"] // daisyUIモーダルのdialogに合わせる
  // dialog要素のcloseイベントを察知する(stimulus以外のcloseアクション、ESCキーを押した時でも)
  // 察知したらhandleDialogCloseを呼び出す
  connect() {
    this.dialogTarget.addEventListener('close', this.handleDialogClose.bind(this));
  }

  // submit成功時用
  formSubmission(event) {
    if (event.detail.success) { // もしフォーム送信が成功したら
      this.dialogTarget.close(); // モーダル閉じる
    }
  }

  // daisyUI, JSデフォルトのcloseメソッドよりも明示的に閉じさせる
  closeModal() {
    this.dialogTarget.close();
  }

  // closeしたことをdialog全体に伝える
  handleDialogClose() {
    this.dispatch('close', { detail: { modal_id: this.dialogTarget.id } });
  }

  // モーダルを閉じた時に中身をクリアにする
  clearModal() {
    const errorMessageFrame = document.getElementById('modal_error_message_frame');
    const sleepLogFrame = document.getElementById('sleep_log_frame');
    console.log("errorMessageFrame", errorMessageFrame);

    if (errorMessageFrame) {
      errorMessageFrame.innerHTML = '';
    }

    if (sleepLogFrame) {
      sleepLogFrame.innerHTML ='';
      sleepLogFrame.removeAttribute('src');
    }
  }

  // メモリリーク対策
  disconnect() {
    this.dialogTarget.removeEventListener('close', this.handleDialogClose.bind(this));
  }
}
