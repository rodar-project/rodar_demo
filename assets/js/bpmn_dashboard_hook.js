import BpmnViewer from "bpmn-js/lib/NavigatedViewer"

const BpmnDashboardHook = {
  mounted() {
    this.viewer = new BpmnViewer({
      container: this.el,
    })

    const xml = this.el.dataset.bpmnXml
    if (xml) {
      this.renderDiagram(xml)
    }

    this.handleEvent("bpmn:update_counts", ({ counts }) => {
      this.updateCounts(counts || {})
    })
  },

  async renderDiagram(xml) {
    try {
      await this.viewer.importXML(xml)
      const canvas = this.viewer.get("canvas")
      canvas.zoom("fit-viewport", "auto")

      // Apply initial counts from data attribute
      const counts = JSON.parse(this.el.dataset.nodeCounts || "{}")
      this.updateCounts(counts)
    } catch (err) {
      console.error("Failed to render BPMN diagram:", err)
    }
  },

  updateCounts(counts) {
    const overlays = this.viewer.get("overlays")
    const elementRegistry = this.viewer.get("elementRegistry")

    // Remove all existing count overlays
    overlays.remove({ type: "node-count" })

    Object.entries(counts).forEach(([nodeId, count]) => {
      const element = elementRegistry.get(nodeId)
      if (!element || count === 0) return

      const isFlow = element.type === "bpmn:SequenceFlow"

      const html = document.createElement("div")
      html.className = isFlow ? "bpmn-count-badge bpmn-count-flow" : "bpmn-count-badge"
      html.textContent = count

      if (isFlow) {
        // Place badge at midpoint of the flow
        overlays.add(nodeId, "node-count", {
          position: { top: -10, left: 0 },
          html,
        })
      } else {
        // Place badge at top-right corner of shapes
        overlays.add(nodeId, "node-count", {
          position: { top: -12, right: -12 },
          html,
        })
      }
    })
  },

  destroyed() {
    if (this.viewer) {
      this.viewer.destroy()
    }
  },
}

export default BpmnDashboardHook
