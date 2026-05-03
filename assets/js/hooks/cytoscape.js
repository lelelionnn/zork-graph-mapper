const baseStyle = [
  {
    selector: "node",
    style: {
      "background-color": "#1f2937",
      "label": "data(label)",
      "color": "#fff",
      "text-valign": "center",
      "text-halign": "center",
      "font-size": 11,
      "width": "label",
      "height": 28,
      "padding": "8px",
      "shape": "round-rectangle",
      "text-wrap": "wrap",
      "text-max-width": "120px"
    }
  },
  {
    selector: "node:selected",
    style: { "background-color": "#2563eb", "border-width": 2, "border-color": "#1e40af" }
  },
  {
    selector: "edge",
    style: {
      "curve-style": "bezier",
      "target-arrow-shape": "triangle",
      "target-arrow-color": "#6b7280",
      "line-color": "#6b7280",
      "label": "data(direction)",
      "font-size": 10,
      "color": "#374151",
      "text-background-color": "#fff",
      "text-background-opacity": 0.9,
      "text-background-padding": 2,
      "width": 2
    }
  },
  {
    selector: "edge:selected",
    style: { "line-color": "#2563eb", "target-arrow-color": "#2563eb", "width": 3 }
  }
]

const nid = (id) => "n" + id
const eid = (id) => "e" + id
const fromNid = (s) => parseInt(s.slice(1), 10)
const fromEid = (s) => parseInt(s.slice(1), 10)

export const Cytoscape = {
  mounted() {
    const cy = cytoscape({
      container: this.el,
      style: baseStyle,
      wheelSensitivity: 0.2
    })
    this.cy = cy
    this.dragTimers = {}

    const initial = JSON.parse(this.el.dataset.graph || '{"rooms":[],"connections":[]}')
    this.loadGraph(cy, initial.rooms, initial.connections)

    cy.on("tap", "node", (evt) => {
      this.pushEventTo(this.el, "room_clicked", { id: fromNid(evt.target.id()) })
    })

    cy.on("tap", "edge", (evt) => {
      this.pushEventTo(this.el, "edge_clicked", { id: fromEid(evt.target.id()) })
    })

    cy.on("tap", (evt) => {
      if (evt.target === cy) {
        this.pushEventTo(this.el, "canvas_clicked", {})
      }
    })

    cy.on("dbltap", (evt) => {
      if (evt.target === cy) {
        const pos = evt.position
        this.pushEventTo(this.el, "create_room", { x: pos.x, y: pos.y })
      }
    })

    cy.on("dragfree", "node", (evt) => {
      const n = evt.target
      const id = fromNid(n.id())
      clearTimeout(this.dragTimers[id])
      this.dragTimers[id] = setTimeout(() => {
        const p = n.position()
        this.pushEventTo(this.el, "room_dragged", { id, x: p.x, y: p.y })
      }, 150)
    })

    this.handleEvent("graph:add_room", (r) => {
      const node = {
        group: "nodes",
        data: { id: nid(r.id), label: r.name }
      }
      if (r.x != null && r.y != null) node.position = { x: r.x, y: r.y }
      cy.add(node)
    })

    this.handleEvent("graph:update_room", (r) => {
      const n = cy.getElementById(nid(r.id))
      if (n.length) n.data("label", r.name)
    })

    this.handleEvent("graph:remove_room", ({ id }) => {
      cy.getElementById(nid(id)).remove()
    })

    this.handleEvent("graph:add_edge", (c) => {
      cy.add({
        group: "edges",
        data: {
          id: eid(c.id),
          source: nid(c.from),
          target: nid(c.to),
          direction: c.direction
        }
      })
    })

    this.handleEvent("graph:update_edge", (c) => {
      const e = cy.getElementById(eid(c.id))
      if (e.length) e.data("direction", c.direction)
    })

    this.handleEvent("graph:remove_edge", ({ id }) => {
      cy.getElementById(eid(id)).remove()
    })

    this.handleEvent("graph:relayout", () => {
      cy.layout({ name: "cose", animate: true, animationDuration: 400 }).run()
    })
  },

  loadGraph(cy, rooms, connections) {
    cy.elements().remove()
    const elements = []
    let needsLayout = false
    rooms.forEach((r) => {
      const node = {
        group: "nodes",
        data: { id: nid(r.id), label: r.name }
      }
      if (r.x != null && r.y != null) {
        node.position = { x: r.x, y: r.y }
      } else {
        needsLayout = true
      }
      elements.push(node)
    })
    connections.forEach((c) => {
      elements.push({
        group: "edges",
        data: {
          id: eid(c.id),
          source: nid(c.from),
          target: nid(c.to),
          direction: c.direction
        }
      })
    })
    cy.add(elements)
    if (needsLayout && rooms.length > 0) {
      cy.layout({ name: "cose", animate: false }).run()
    } else if (rooms.length > 0) {
      cy.fit(undefined, 50)
    }
  },

  destroyed() {
    if (this.cy) this.cy.destroy()
  }
}
