import BpmnViewer from "bpmn-js/lib/NavigatedViewer"

const BpmnViewerHook = {
  mounted() {
    this.viewer = new BpmnViewer({
      container: this.el,
    })

    const xml = this.el.dataset.bpmnXml
    if (xml) {
      this.renderDiagram(xml)
    }

    this.handleEvent("bpmn:update_state", ({ visited, active }) => {
      this.updateMarkers(visited || [], active || [])
    })
  },

  async renderDiagram(xml) {
    try {
      await this.viewer.importXML(xml)
      const canvas = this.viewer.get("canvas")
      canvas.zoom("fit-viewport", "auto")

      this.highlightUserTasks()

      // Apply initial state from data attributes
      const visited = JSON.parse(this.el.dataset.visitedNodes || "[]")
      const active = JSON.parse(this.el.dataset.activeNodes || "[]")
      this.updateMarkers(visited, active)
    } catch (err) {
      console.error("Failed to render BPMN diagram:", err)
    }
  },

  updateMarkers(visited, active) {
    const canvas = this.viewer.get("canvas")
    const elementRegistry = this.viewer.get("elementRegistry")

    // Clear all existing markers
    elementRegistry.forEach((element) => {
      canvas.removeMarker(element.id, "bpmn-visited")
      canvas.removeMarker(element.id, "bpmn-active")
    })

    // Add visited markers (completed nodes)
    visited.forEach((nodeId) => {
      if (elementRegistry.get(nodeId)) {
        canvas.addMarker(nodeId, "bpmn-visited")
      }
    })

    // Add active markers (current node awaiting action)
    active.forEach((nodeId) => {
      if (elementRegistry.get(nodeId)) {
        canvas.addMarker(nodeId, "bpmn-active")
      }
    })
  },

  highlightUserTasks() {
    const canvas = this.viewer.get("canvas")
    const elementRegistry = this.viewer.get("elementRegistry")

    elementRegistry.forEach((element) => {
      if (element.type === "bpmn:UserTask") {
        canvas.addMarker(element.id, "bpmn-user-task")
      }
    })
  },

  destroyed() {
    if (this.viewer) {
      this.viewer.destroy()
    }
  },
}

export default BpmnViewerHook
