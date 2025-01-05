// This file is auto-generated by ./bin/rails stimulus:manifest:update
// Run that command whenever you add a new controller or create them with
// ./bin/rails generate stimulus controllerName

// from~Toggle)まで追加。TailwindCSSコンポーネントをインポート
import { application } from "@hotwired/stimulus" // from "./application"

const application = application.start();

// TailwindCSS Components https://github.com/excid3/tailwindcss-stimulus-components#basic-usage TODO: 不要なものがあれば消すこと
import { Modal } from "tailwindcss-stimulus-components"
application.register('modal', Modal)

import HelloController from "./hello_controller"
application.register("hello", HelloController)
