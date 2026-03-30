// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/maestro"
import TableHooks from "../../deps/live_table/priv/static/live-table.js"
import topbar from "../vendor/topbar"
import Sortable from "sortablejs"
import EasyMDE from "easymde"

const SortableHook = {
  mounted() {
    const sortable = new Sortable(this.el, {
      animation: 150,
      ghostClass: 'opacity-50',
      handle: '.drag-handle',
      onEnd: (evt) => {
        const items = Array.from(this.el.children).map((child, index) => ({
          path: child.dataset.path,
          index: index
        }));
        this.pushEvent("reorder_startup", {items: items, project: this.el.dataset.project});
      }
    });
  }
};

const MarkdownEditorHook = {
  mounted() {
    const textarea = this.el;
    const easyMDE = new EasyMDE({
      element: textarea,
      spellChecker: false,
      toolbar: ["bold", "italic", "heading", "|", "quote", "unordered-list", "ordered-list", "|", "link", "image", "|", "preview", "side-by-side", "fullscreen"],
      status: false,
      initialValue: textarea.value || ""
    });
    
    // Auto-format raw content when editor first loads
    const initialValue = textarea.value || "";
    if (initialValue && !this.isAlreadyFormatted(initialValue)) {
      const formatted = this.formatContent(initialValue);
      easyMDE.value(formatted);
      textarea.value = formatted;
    }
    
    easyMDE.codemirror.on("change", () => {
      textarea.value = easyMDE.value();
      textarea.dispatchEvent(new Event('input', { bubbles: true }));
    });
    
    // Auto-format on blur (when user finishes editing)
    easyMDE.codemirror.on("blur", () => {
      const currentValue = easyMDE.value();
      if (currentValue && !this.isAlreadyFormatted(currentValue)) {
        const formatted = this.formatContent(currentValue);
        easyMDE.value(formatted);
        textarea.value = formatted;
        textarea.dispatchEvent(new Event('input', { bubbles: true }));
      }
    });
    
    this.handleEvent("clear-editor", () => {
      easyMDE.value("");
    });
  },
  
  isAlreadyFormatted(content) {
    // Check if content already has markdown structure
    return content.includes('## ') || content.includes('### ') || content.includes('**') || content.includes('- [');
  },
  
  formatContent(content) {
    const trimmed = content.trim();
    if (!trimmed) return trimmed;
    
    // Basic formatting for raw text/chat dumps
    return `# Topic

## Overview

${trimmed}

## Status

- [ ] In Progress

## Notes

(Add notes here)`;
  }
};

const GitDropdownHook = {
  mounted() {
    this.button = this.el.querySelector('#git-dropdown-button');
    this.menu = this.el.querySelector('#git-dropdown-menu');
    this.loaded = false;
    
    this.button.addEventListener('click', () => {
      if (!this.loaded) {
        this.loadGitInfo();
      } else {
        this.toggleMenu();
      }
    });
    
    document.addEventListener('click', (e) => {
      if (!this.el.contains(e.target)) {
        this.hideMenu();
      }
    });
  },
  
  async loadGitInfo() {
    const projectPath = this.el.dataset.projectPath;
    const url = projectPath ? `/api/git/info?project_path=${encodeURIComponent(projectPath)}` : '/api/git/info';
    
    try {
      const response = await fetch(url);
      const data = await response.json();
      this.renderGitInfo(data);
      this.loaded = true;
      this.showMenu();
    } catch (error) {
      console.error('Failed to load git info:', error);
    }
  },
  
  renderGitInfo(data) {
    const branchLabel = this.el.querySelector('#git-branch-label');
    const commitsAhead = this.el.querySelector('#git-commits-ahead');
    const commitsBehind = this.el.querySelector('#git-commits-behind');
    const currentBranch = this.el.querySelector('#git-current-branch');
    const otherBranches = this.el.querySelector('#git-other-branches');
    
    branchLabel.textContent = data.current_branch;
    currentBranch.textContent = data.current_branch;
    
    if (data.commits_ahead) {
      commitsAhead.innerHTML = `<span class="badge badge-xs badge-warning">+${data.commits_ahead}</span>`;
    }
    
    if (data.commits_behind) {
      commitsBehind.innerHTML = `<span class="badge badge-xs badge-error">-${data.commits_behind}</span>`;
    }
    
    if (data.other_branches && data.other_branches.length > 0) {
      const branchesHTML = data.other_branches.map(b => `
        <li>
          <div class="flex items-center justify-between">
            <span class="font-mono text-xs">${b.branch}</span>
            <div class="flex gap-1">
              ${b.ahead ? `<span class="badge badge-xs badge-warning">+${b.ahead}</span>` : ''}
              ${b.behind ? `<span class="badge badge-xs badge-error">-${b.behind}</span>` : ''}
            </div>
          </div>
        </li>
      `).join('');
      
      otherBranches.innerHTML = `
        <li class="menu-title mt-2">Other Branches</li>
        ${branchesHTML}
      `;
    }
  },
  
  showMenu() {
    this.menu.style.display = 'block';
  },
  
  hideMenu() {
    this.menu.style.display = 'none';
  },
  
  toggleMenu() {
    if (this.menu.style.display === 'none') {
      this.showMenu();
    } else {
      this.hideMenu();
    }
  }
};

const ShiftClickHook = {
  mounted() {
    this.el.addEventListener('click', (e) => {
      if (e.shiftKey && !e.target.closest('a')) {
        e.preventDefault();
        this.pushEvent('toggle_fullscreen', {});
      }
    });
  }
};

const AgentDashboard = {
  mounted() {
    const saved = localStorage.getItem("agent-dashboard-expanded");
    if (saved !== null) {
      this.pushEventTo("#agent-dashboard", "restore_state", { expanded: saved === "true" });
    }
    this.handleEvent("dashboard-state", ({ expanded }) => {
      localStorage.setItem("agent-dashboard-expanded", expanded);
    });
  }
};

const Mermaid = {
  mounted() {
    this.renderDiagram();
  },
  updated() {
    this.renderDiagram();
  },
  renderDiagram() {
    const code = this.el.dataset.mermaid;
    if (!code) return;
    if (!window.mermaid) {
      const script = document.createElement("script");
      script.src = "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js";
      script.onload = () => {
        window.mermaid.initialize({ startOnLoad: false, theme: "dark" });
        this.doRender(code);
      };
      document.head.appendChild(script);
    } else {
      this.doRender(code);
    }
  },
  async doRender(code) {
    const id = "mermaid-" + Date.now();
    try {
      const { svg } = await window.mermaid.render(id, code);
      this.el.innerHTML = svg;
    } catch (e) {
      this.el.innerHTML = "<pre class='text-error text-sm'>" + e.message + "</pre><pre class='text-xs opacity-50 mt-2'>" + code.replace(/</g, "&lt;") + "</pre>";
    }
  }
};

const ProjectGitInfoHook = {
  mounted() {
    const projectId = this.el.dataset.projectId;
    const projectPath = this.el.dataset.projectPath;
    const button = this.el.querySelector('button');

    button.addEventListener('click', () => this.loadGitInfo(projectId, projectPath));
  },

  async loadGitInfo(projectId, projectPath) {
    const url = `/api/git/info?project_path=${encodeURIComponent(projectPath)}`;

    try {
      const response = await fetch(url);
      const data = await response.json();

      this.el.querySelector(`#git-branch-${projectId}`).textContent = data.current_branch;
      this.el.querySelector(`#git-current-${projectId}`).textContent = data.current_branch;

      let badgesHTML = '';
      if (data.commits_ahead) {
        badgesHTML += `<span class="badge badge-warning">+${data.commits_ahead} ahead</span>`;
      }
      if (data.commits_behind) {
        badgesHTML += `<span class="badge badge-error">-${data.commits_behind} behind</span>`;
      }
      this.el.querySelector(`#git-badges-${projectId}`).innerHTML = badgesHTML;

      if (data.other_branches && data.other_branches.length > 0) {
        const branchesHTML = '<div class="text-sm text-base-content/60 mb-2">Other Branches</div>' +
          data.other_branches.slice(0, 5).map(b => `
            <div class="flex items-center justify-between py-1">
              <span class="font-mono text-sm">${b.branch}</span>
              <div class="flex gap-1">
                ${b.ahead ? `<span class="badge badge-xs badge-warning">+${b.ahead}</span>` : ''}
                ${b.behind ? `<span class="badge badge-xs badge-error">-${b.behind}</span>` : ''}
              </div>
            </div>
          `).join('');

        this.el.querySelector(`#git-branches-${projectId}`).innerHTML = branchesHTML;
      }

      this.el.querySelector(`#git-info-${projectId}`).style.display = 'block';
    } catch (err) {
      console.error('Failed to load git info:', err);
    }
  }
};

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...TableHooks, SortableHook, MarkdownEditorHook, GitDropdownHook, ProjectGitInfoHook, ShiftClickHook, AgentDashboard, Mermaid},
})

window.addEventListener("phx:theme-changed", (e) => {
  const theme = e.detail.theme;
  if (theme === "both") {
    document.documentElement.removeAttribute("data-theme");
  } else {
    document.documentElement.setAttribute("data-theme", theme);
  }
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
