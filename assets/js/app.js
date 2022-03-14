// We import the CSS which is extracted to its own file by esbuild.
// Remove this line if you add a your own CSS build pipeline (e.g postcss).
import "../css/app.css"

// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "./vendor/some-package.js"
//
// Alternatively, you can `npm install some-package` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"
import { get_cookie, set_cookie } from "./cookies"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let hooks = {}
hooks.txt_tree = {
  mounted() {
    const param = decodeURIComponent(((window.location.search || "").match(/(\?|&)tree\=([^&]*)/) || [null, null])[2] || "")
    if (param) {
      this.pushEvent("compressed_tree", { "data": param })
    } else {
      const saved_tree = get_cookie("tree")

      if (saved_tree) {
        this.el.value = saved_tree
        this.pushEvent("tree", { "tree": saved_tree })
        this.el.setAttribute("phx-update", "ignore")
      }
    }

    this.el.addEventListener("input", () => {
      set_cookie("tree", this.el.value)
    })

    this.el.addEventListener("keydown", e => {
      if (e.keyCode == 9) {
        e.preventDefault()
        const cursor_position = this.el.selectionStart
        this.el.value = this.el.value.slice(0, this.el.selectionStart) + "  " + this.el.value.slice(this.el.selectionEnd)
        this.el.selectionStart = cursor_position + 2
        this.el.selectionEnd = cursor_position + 2
      }
    })
  }
}
let liveSocket = new LiveSocket("/live", Socket, { params: { _csrf_token: csrfToken }, hooks: hooks })

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _ => topbar.show())
window.addEventListener("phx:page-loading-stop", _ => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
