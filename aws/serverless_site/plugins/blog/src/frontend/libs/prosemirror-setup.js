// ::Schema Document schema for the data model used by CommonMark.
const schema = new prosemirror.Schema({
  nodes: {
    doc: {
      content: "(block | image)+"
    },

    paragraph: {
      content: "inline*",
      group: "block",
      parseDOM: [{tag: "p"}],
      toDOM() { return ["p", 0] }
    },

    blockquote: {
      content: "block+",
      group: "block",
      parseDOM: [{tag: "blockquote"}],
      toDOM() { return ["blockquote", 0] }
    },

    horizontal_rule: {
      group: "block",
      parseDOM: [{tag: "hr"}],
      toDOM() { return ["div", ["hr"]] }
    },

    heading: {
      attrs: {level: {default: 1}},
      content: "text*",
      group: "block",
      defining: true,
      parseDOM: [
                 {tag: "h2", attrs: {level: 1}},
                 {tag: "h3", attrs: {level: 2}},
                 {tag: "h4", attrs: {level: 3}},
                ],
      toDOM(node) { return ["h" + node.attrs.level, 0] }
    },

    code_block: {
      content: "text*",
      group: "block",
      code: true,
      defining: true,
      marks: "",
      attrs: {params: {default: ""}},
      parseDOM: [{tag: "pre", preserveWhitespace: "full", getAttrs: node => (
        {params: node.getAttribute("data-params") || ""}
      )}],
      toDOM(node) { return ["pre", node.attrs.params ? {"data-params": node.attrs.params} : {}, ["code", 0]] }
    },

    ordered_list: {
      content: "list_item+",
      group: "block",
      attrs: {order: {default: 1}, tight: {default: false}},
      parseDOM: [{tag: "ol", getAttrs(dom) {
        return {order: dom.hasAttribute("start") ? +dom.getAttribute("start") : 1,
                tight: dom.hasAttribute("data-tight")}
      }}],
      toDOM(node) {
        return ["ol", {start: node.attrs.order == 1 ? null : node.attrs.order,
                       "data-tight": node.attrs.tight ? "true" : null}, 0]
      }
    },

    bullet_list: {
      content: "list_item+",
      group: "block",
      attrs: {tight: {default: false}},
      parseDOM: [{tag: "ul", getAttrs: dom => ({tight: dom.hasAttribute("data-tight")})}],
      toDOM(node) { return ["ul", {"data-tight": node.attrs.tight ? "true" : null}, 0] }
    },

    list_item: {
      content: "paragraph block*",
      defining: true,
      parseDOM: [{tag: "li"}],
      toDOM() { return ["li", 0] }
    },

    text: {
      group: "inline"
    },

		footnote_ref:{
			group: "inline",
			content: "inline*",
			inline: true,
			draggable: true,
			// This makes the view treat the node as a leaf, even though it
			// technically has content
			atom: true,
			attrs: {
				ref: {},  
			},
			toDOM: (node) =>  ['sup'],
				parseDOM: [{tag: "sup", getAttrs(dom) {
				return {
					ref: dom.innerText
				}
			}}]
		}, 

    image: {
      attrs: {
        src: {},
        alt: {default: null},
        title: {default: null},
        file: {default: null},
        imageId: {default: null},
        postId: {default: null},
        size: {default: null},
        canonicalExt: {default: null},
      },
      parseDOM: [{tag: "img[src]", getAttrs(dom) {
        return {
          src: dom.getAttribute("src"),
          title: dom.getAttribute("title").replaceAll(/\n+/g, "\n"),
          alt: dom.getAttribute("alt").replaceAll(/\n+/g, "\n"),
        }
      }}],
      toDOM(node) { return ["img", node.attrs] }
    },

    hard_break: {
      inline: true,
      group: "inline",
      selectable: false,
      parseDOM: [{tag: "br"}],
      toDOM() { return ["br"] }
    }
  },

  marks: {
    em: {
      parseDOM: [{tag: "i"}, {tag: "em"},
                 {style: "font-style", getAttrs: value => value == "italic" && null}],
      toDOM() { return ["em"] }
    },

    strong: {
      parseDOM: [{tag: "b"}, {tag: "strong"},
                 {style: "font-weight", getAttrs: value => /^(bold(er)?|[5-9]\d{2,})$/.test(value) && null}],
      toDOM() { return ["strong"] }
    },

    link: {
      attrs: {
        href: {},
        title: {default: null}
      },
      inclusive: false,
      parseDOM: [{tag: "a[href]", getAttrs(dom) {
        return {href: dom.getAttribute("href"), title: dom.getAttribute("title")}
      }}],
      toDOM(node) { return ["a", node.attrs] }
    },

    code: {
      parseDOM: [{tag: "code"}],
      toDOM() { return ["code"] }
    }
  }
})

function listIsTight(tokens, i) {
  while (++i < tokens.length) {
    if (tokens[i].type != "list_item_open") {
      return tokens[i].hidden 
    }
  }
  return false
}

const md = markdownit("commonmark", {html: false, }).use(footnote_plugin, {parse_defs: false})
const oldParse = md.parse
md.parse = function(...args) {
  const tokenList = oldParse.apply(md, args)
  let ret = []
  let current = tokenList.shift()
  while (current) {
    if (current.type === 'paragraph_open') {
      let paragraphOpen = current
      let paragraphContents = []
      current = tokenList.shift()
      while (current.type !== 'paragraph_close') {
        paragraphContents.push(current)
        current = tokenList.shift()
      }
      let paragraphClose = current
      if (paragraphContents.length === 1 && _.get(paragraphContents, '[0].children.length') === 1 && _.get(paragraphContents, '[0].children[0].type') === 'image') {
        ret.push(paragraphContents[0].children[0])
      } else {
        paragraphContents.unshift(paragraphOpen)
        paragraphContents.push(paragraphClose)
        ret = _.concat(ret, paragraphContents)
      }
    } else {
      ret.push(current)
    }
    current = tokenList.shift()
  }
  return ret
}


const footnoteMarkdownParser = new prosemirror.MarkdownParser(schema, md, {
  blockquote: {block: "blockquote"},
  paragraph: {block: "paragraph"},
  list_item: {block: "list_item"},
  bullet_list: {block: "bullet_list", getAttrs: (_, tokens, i) => ({tight: listIsTight(tokens, i)})},
  ordered_list: {block: "ordered_list", getAttrs: (tok, tokens, i) => ({
    order: +tok.attrGet("start") || 1,
    tight: listIsTight(tokens, i)
  })},
  heading: {block: "heading", getAttrs: tok => ({level: +tok.tag.slice(1)})},
  code_block: {block: "code_block", noCloseToken: true},
  fence: {block: "code_block", getAttrs: tok => ({params: tok.info || ""}), noCloseToken: true},
  hr: {node: "horizontal_rule"},
  image: {node: "image", getAttrs: tok => {
    const {originalUrl, postId, imageId, size, canonicalExt} = parseImageUrl(tok.attrGet("src"))
    const ret = {
      src: originalUrl,
      postId,
      imageId,
      size,
      canonicalExt,
      title: tok.attrGet("title") || null,
      alt: tok.attrGet("title") || null,
    }
    return ret
  }},
  footnote_ref: {
    node: "footnote_ref",
    getAttrs: (tok) => {
      return {ref: tok.meta.ref}
    }
  },
  hardbreak: {node: "hard_break"},

  em: {mark: "em"},
  strong: {mark: "strong"},
  link: {mark: "link", getAttrs: tok => ({
    href: tok.attrGet("href"),
    title: tok.attrGet("title") || null
  })},
  code_inline: {mark: "code", noCloseToken: true}
})

footnoteMarkdownParser.tokenHandlers.softbreak = (state, tok) => {
  state.addText(" ")
}

class FootnoteView {
  constructor(node, view, getPos) {
    // We'll need these later
    this.node = node
    this.outerView = view

    // The node's representation in the editor (empty, for now)
    this.dom = document.createElement("sup")
    this.dom.innerText = node.attrs.ref
    this.getPos = getPos
  }

  selectNode() {
    this.dom.classList.add("ProseMirror-selectednode")
  }

  deselectNode() {
    this.dom.classList.remove("ProseMirror-selectednode")
  }

  ignoreMutation() { return true }
}

function moveUp(view, node, getPos, evt) {
  evt.stopPropagation()
  const state = view.state
  const doc = view.state.doc
  const tr = view.state.tr
  const startingPos = getPos()
  let previous = doc.childBefore(startingPos)
  if (!previous) {
    return
  }
  const newPos = previous.offset
  tr.setSelection(new prosemirror.NodeSelection(doc.resolve(startingPos)))
  .deleteSelection()
  .insert(newPos, node)
  .setSelection(new prosemirror.NodeSelection(tr.doc.resolve(newPos)))
  view.dispatch(tr)
}

function updateTextDescriptionArea(view, node, getPos, evt) {
  evt.stopPropagation()
  const tr = view.state.tr.setNodeMarkup(
    getPos(),
    null,
    {
      src: node.attrs.src,
      alt: evt.target.value,
      title: evt.target.value,
    }
  )
  view.dispatch(tr)
}

function moveDown(view, node, getPos, evt) {
  evt.stopPropagation()
  const state = view.state
  const doc = view.state.doc
  const tr = view.state.tr
  const startingPos = getPos()
  const next = doc.childAfter(startingPos + 1)
  if (!next || !next.node) {
    return
  }
  const newPos = next.offset + next.node.nodeSize
  tr.setSelection(new prosemirror.NodeSelection(doc.resolve(startingPos)))
  .deleteSelection()
  .insert(tr.mapping.map(newPos), node)
  .setSelection(new prosemirror.NodeSelection(tr.doc.resolve(tr.doc.childBefore(tr.mapping.map(newPos)).offset)))
  view.dispatch(tr)
}

function deselectImage(view, node, getPos, evt) {
  evt.stopPropagation()
  const state = view.state
  const doc = view.state.doc
  const tr = view.state.tr
  const startingPos = getPos()
  tr.setSelection(new prosemirror.TextSelection(doc.resolve(startingPos + 1)))
  view.dispatch(tr)
}

function findNode(node, predicate) {
  let found
  node.descendants((node, pos) => {
    if (predicate(node)) {
      found = {node, pos}
    }
    if (found) {
      return false
    }
  })
  return found
}

class ImageView {
  constructor(node, view, getPos) {
    // We'll need these later
    this.node = node
    this.view = view
    const hasFile = node.attrs.file && node.attrs.file instanceof File
    this.getPos = getPos
    const self = this

    // The node's representation in the editor (empty, for now)
    this.dom = domNode({
      tagName: 'div',
      onClick: (evt) => evt.stopPropagation(),
      classNames: 'authoring-image-container',
      children: [
        {
          tagName: 'button',
          classNames: ['image-bump-up', 'img-control'],
          onClick: _.partial(moveUp, self.view, self.node, self.getPos),
          children: [
            {
              tagName: 'svg',
              width: '5em',
              height: '2.5em',
              viewBox: '0 0 100 50',
              children: [
                {
                  tagName: 'polyline',
                  points: [{
                    x: 10,
                    y: 40,
                  },
                  {
                    x: 50,
                    y: 10,
                  }, 
                  {
                    x: 90,
                    y: 40,
                  },
                  ],
                  strokeWidth: '0.4em',
                  stroke: '#1a1a1a',
                  strokeLinecap: 'round',
                  strokeLinejoin: 'round',
                  fill: 'transparent',
                }
              ]
            }
          ]
        },
        {
          tagName: 'img',
          onClick: (evt) => evt.stopPropagation(),
          src: hasFile ? URL.createObjectURL(node.attrs.file) : node.attrs.src,
          title: node.attrs.title,
          alt: node.attrs.alt,
        },
        {
          tagName: 'label',
          classNames: ['img-control', 'img-description-label'],
          children: [
            I18N_CONFIG.ui.textDescription + I18N_CONFIG.ui.colonMarker
          ]
        },
        {
          tagName: 'textarea',
          classNames: ['image-text-description', 'img-control'],
          //onClick: _.partial(updateTextDescription, self.view, self.node, self.getPos),
          onClick: (evt) => evt.stopPropagation(),
          onInput: _.partial(updateTextDescriptionArea, self.view, self.node, self.getPos),
          value: this.node.attrs.alt || '',
          placeholder: I18N_CONFIG.ui.textDescription
        },
        {
          tagName: 'button',
          classNames: ['img-control'],
          onClick: _.partial(deselectImage, self.view, self.node, self.getPos),
          children: [
            I18N_CONFIG.ui.deselect
          ]
        },
        {
          tagName: 'button',
          classNames: ['image-bump-down', 'img-control'],
          onClick: _.partial(moveDown, self.view, self.node, self.getPos),
          children: [
            {
              tagName: 'svg',
              width: '5em',
              height: '2.5em',
              viewBox: '0 0 100 50',
              children: [
                {
                  tagName: 'polyline',
                  points: [{
                    x: 10,
                    y: 10,
                  },
                  {
                    x: 50,
                    y: 40,
                  }, 
                  {
                    x: 90,
                    y: 10,
                  },
                  ],
                  strokeWidth: '0.4em',
                  stroke: '#1a1a1a',
                  strokeLinecap: 'round',
                  strokeLinejoin: 'round',
                  fill: 'transparent',
                }
              ]
            }
          ]
        },
      ]
    })
    if (hasFile) {
      const spinnaNode = domNode(svgs.hex)
      const spinAnimation = svgNode(svgs.spin)
      const spinnable = spinnaNode.querySelector('.spinnable')
      spinnable.appendChild(spinAnimation)
      this.dom.appendChild(spinnaNode)
      node.attrs.file.arrayBuffer().then((buffer) => {
        window.goph.report(
          'pollImage',
          {
            imageExt: node.attrs.canonicalExt,
            postId: node.attrs.postId,
            imageId: node.attrs.imageId,
            imageSize: node.attrs.size,
            buffer,
          },
          (e, r) => {
            if (e) {
              console.error(e)
            }
            this.dom.removeChild(spinnaNode)
            const tr = view.state.tr.setNodeMarkup(
              self.getPos(),
              null,
              {
                src: node.attrs.src,
                file: null,
                size: self.node.attrs.size,
                canonicalExt: self.node.attrs.canonicalExt,
                postId: self.node.attrs.postId,
                imageId: self.node.attrs.imageId,
                alt: (self.node.attrs.alt || '').replaceAll(/\n+/g, "\n"),
                title: (self.node.attrs.title || '').replaceAll(/\n+/g, "\n"),
              }
            )
            view.dispatch(tr)
          }
        )
      })
    }
  }

  stopEvent(evt) {
    if (this.isSelected) {
      return true
    }
  }

  ignoreMutation() { return true }

  selectNode() {
    this.isSelected = true
    const self = this
    this.dom.classList.add("ProseMirror-selectednode")
  }

  deselectNode() {
    this.isSelected = false
    this.dom.classList.remove("ProseMirror-selectednode")
  }

  update(node) {
    if (node.type.name === "image") {
      this.node = node
      return true
    }
  }
}

function isPlainURL(link, parent, index, side) {
  if (link.attrs.title || !/^\w+:/.test(link.attrs.href)) return false
    let content = parent.child(index + (side < 0 ? -1 : 0))
  if (!content.isText || content.text != link.attrs.href || content.marks[content.marks.length - 1] != link) return false
    if (index == (side < 0 ? 1 : parent.childCount - 1)) return true
      let next = parent.child(index + (side < 0 ? -2 : 1))
  return !link.isInSet(next.marks)
}

function backticksFor(node, side) {
  let ticks = /`+/g, m, len = 0
  if (node.isText) while (m = ticks.exec(node.text)) len = Math.max(len, m[0].length)
    let result = len > 0 && side > 0 ? " `" : "`"
  for (let i = 0; i < len; i++) result += "`"
  if (len > 0 && side < 0) result += " "
    return result
}

const footnoteMarkdownSerializer = new prosemirror.MarkdownSerializer({
  blockquote(state, node) {
    state.wrapBlock("> ", null, node, () => state.renderContent(node))
  },
  code_block(state, node) {
    state.write("```" + (node.attrs.params || "") + "\n")
    state.text(node.textContent, false)
    state.ensureNewLine()
    state.write("```")
    state.closeBlock(node)
  },
  heading(state, node) {
    state.write(state.repeat("#", node.attrs.level) + " ")
    state.renderInline(node)
    state.closeBlock(node)
  },
  horizontal_rule(state, node) {
    state.write(node.attrs.markup || "---")
    state.closeBlock(node)
  },
  bullet_list(state, node) {
    state.renderList(node, "  ", () => (node.attrs.bullet || "*") + " ")
  },
  ordered_list(state, node) {
    let start = node.attrs.order || 1
    let maxW = String(start + node.childCount - 1).length
    let space = state.repeat(" ", maxW + 2)
    state.renderList(node, space, i => {
      let nStr = String(start + i)
      return state.repeat(" ", maxW - nStr.length) + nStr + ". "
    })
  },
  list_item(state, node) {
    state.renderContent(node)
  },
  paragraph(state, node) {
    state.renderInline(node)
    state.closeBlock(node)
  },

  image(state, node) {
    state.write("![" + state.esc((node.attrs.alt || "").replaceAll(/\n+/g, "\n")) + "](" + state.esc(node.attrs.src) + (node.attrs.alt ? ` ${state.quote(node.attrs.alt.replaceAll(/\n+/g, "\n"))}` : '') + ')')
    state.closeBlock(node)
  },
  hard_break(state, node, parent, index) {
    for (let i = index + 1; i < parent.childCount; i++)
      if (parent.child(i).type != node.type) {
        state.write("\\\n")
        return
      }
  },
  text(state, node) {
    state.text(node.text.replaceAll(/(.{75,100}) /g, (m, g) => g + '\n'))
  },

  footnote_ref(state, node) {
    state.write('[^' + node.attrs.ref + ']')
  }

}, {
  em: {open: "*", close: "*", mixable: true, expelEnclosingWhitespace: true},
  strong: {open: "**", close: "**", mixable: true, expelEnclosingWhitespace: true},
  link: {
    open(_state, mark, parent, index) {
      return isPlainURL(mark, parent, index, 1) ? "<" : "["
    },
    close(state, mark, parent, index) {
      return isPlainURL(mark, parent, index, -1) ? ">"
        : "](" + state.esc(mark.attrs.href) + (mark.attrs.title ? " " + state.quote(mark.attrs.title) : "") + ")"
    }
  },
  code: {open(_state, _mark, parent, index) { return backticksFor(parent.child(index), -1) },
         close(_state, _mark, parent, index) { return backticksFor(parent.child(index - 1), 1) },
         escape: false}
})

// PROMPT
//
const prefix = "ProseMirror-prompt"

function openPrompt(options) {
  let wrapper = document.body.appendChild(document.createElement("div"))
  wrapper.className = prefix

  let mouseOutside = e => { if (!wrapper.contains(e.target)) close() }
  setTimeout(() => window.addEventListener("mousedown", mouseOutside), 50)
  let close = () => {
    window.removeEventListener("mousedown", mouseOutside)
    if (wrapper.parentNode) wrapper.parentNode.removeChild(wrapper)
  }

  let domFields = []
  for (let name in options.fields) domFields.push(options.fields[name].render())

  let submitButton = document.createElement("button")
  submitButton.type = "submit"
  submitButton.className = prefix + "-submit"
  submitButton.textContent = I18N_CONFIG.ui.ok
  let cancelButton = document.createElement("button")
  cancelButton.type = "button"
  cancelButton.className = prefix + "-cancel"
  cancelButton.textContent = I18N_CONFIG.ui.cancel
  cancelButton.addEventListener("click", close)

  let form = wrapper.appendChild(document.createElement("form"))
  if (options.title) form.appendChild(document.createElement("h5")).textContent = options.title
  domFields.forEach(field => {
    const fieldWrapper = document.createElement("div")
    fieldWrapper.className = "prompt-field-wrapper"
    fieldWrapper.appendChild(field)
    form.appendChild(fieldWrapper)
  })
  let buttons = form.appendChild(document.createElement("div"))
  buttons.className = prefix + "-buttons"
  buttons.appendChild(submitButton)
  buttons.appendChild(document.createTextNode(" "))
  buttons.appendChild(cancelButton)

  let box = wrapper.getBoundingClientRect()
  wrapper.style.top = ((window.innerHeight - box.height) / 2) + "px"
  wrapper.style.left = ((window.innerWidth - box.width) / 2) + "px"

  let submit = () => {
    let params = getValues(options.fields, domFields)
    if (params) {
      close()
      options.callback(params)
    }
  }

  form.addEventListener("submit", e => {
    e.preventDefault()
    submit()
  })

  form.addEventListener("keydown", e => {
    if (e.keyCode == 27) {
      e.preventDefault()
      close()
    } else if (e.keyCode == 13 && !(e.ctrlKey || e.metaKey || e.shiftKey)) {
      e.preventDefault()
      submit()
    } else if (e.keyCode == 9) {
      window.setTimeout(() => {
        if (!wrapper.contains(document.activeElement)) close()
      }, 500)
    }
  })

  let input = form.elements[0]
  if (input) input.focus()
}

function getValues(fields, domFields) {
  let result = Object.create(null), i = 0
  for (let name in fields) {
    let field = fields[name], dom = domFields[i++]
    let value = field.read(dom), bad = field.validate(value)
    if (bad) {
      reportInvalid(dom, bad)
      return null
    }
    result[name] = field.clean(value)
  }
  return result
}

function reportInvalid(dom, message) {
  // FIXME this is awful and needs a lot more work
  let parent = dom.parentNode
  let msg = parent.appendChild(document.createElement("div"))
  msg.style.left = (dom.offsetLeft + dom.offsetWidth + 2) + "px"
  msg.style.top = (dom.offsetTop - 5) + "px"
  msg.className = "ProseMirror-invalid"
  msg.textContent = message
  setTimeout(() => parent.removeChild(msg), 1500)
}

// ::- The type of field that `FieldPrompt` expects to be passed to it.
class Field {
  // :: (Object)
  // Create a field with the given options. Options support by all
  // field types are:
  //
  // **`value`**`: ?any`
  //   : The starting value for the field.
  //
  // **`label`**`: string`
  //   : The label for the field.
  //
  // **`required`**`: ?bool`
  //   : Whether the field is required.
  //
  // **`validate`**`: ?(any) → ?string`
  //   : A function to validate the given value. Should return an
  //     error message if it is not valid.
  constructor(options) { this.options = options }

  // render:: (state: EditorState, props: Object) → dom.Node
  // Render the field to the DOM. Should be implemented by all subclasses.

  // :: (dom.Node) → any
  // Read the field's value from its DOM node.
  read(dom) { return dom.value }

  // :: (any) → ?string
  // A field-type-specific validation function.
  validateType(_value) {}

  validate(value) {
    if (!value && this.options.required)
      return I18N_CONFIG.ui.required
    return this.validateType(value) || (this.options.validate && this.options.validate(value))
  }

  clean(value) {
    return this.options.clean ? this.options.clean(value) : value
  }
}

// ::- A field class for single-line text fields.
class TextField extends Field {
  render() {
    let input = document.createElement("input")
    input.type = "text"
    input.placeholder = this.options.label
    input.className = this.options.className
    input.value = this.options.value || ""
    input.autocomplete = "off"
    return input
  }
}

// ::- A field class for single-line text fields.
class TextAreaField extends Field {
  render() {
    let area = document.createElement("textarea")
    area.placeholder = this.options.label
    area.className = this.options.className
    area.value = this.options.value || ""
    return area
  }
}

// ::- A field class for single-line text fields.
class FileField extends Field {
  read(dom) { 
    return dom.querySelector('input').files[0]
  }
  render() {
    let input = domNode({
      tagName: 'label',
      classNames: 'file',
      children: [
        {
          tagName: 'input',
          type: 'file',
        },
        {
          tagName: 'span',
          classNames: 'file-custom'
        }
      ]
    })
    return input
  }
}


// ::- A field class for dropdown fields based on a plain `<select>`
// tag. Expects an option `options`, which should be an array of
// `{value: string, label: string}` objects, or a function taking a
// `ProseMirror` instance and returning such an array.
class SelectField extends Field {
  render() {
    let select = document.createElement("select")
    select.className = this.options.className
    this.options.options.forEach(o => {
      let opt = select.appendChild(document.createElement("option"))
      opt.value = o.value
      opt.selected = o.value == this.options.value
      opt.label = o.label
    })
    return select
  }
}


// MENU

function canInsert(state, nodeType) {
  let $from = state.selection.$from
  for (let d = $from.depth; d >= 0; d--) {
    let index = $from.index(d)
    if ($from.node(d).canReplaceWith(index, index, nodeType)) return true
  }
  return false
}

function cmdItem(cmd, options) {
  let passedOptions = {
    label: options.title,
    run: cmd
  }
  for (let prop in options) passedOptions[prop] = options[prop]
  if ((!options.enable || options.enable === true) && !options.select)
    passedOptions[options.enable ? "enable" : "select"] = state => cmd(state)

  return new prosemirror.MenuItem(passedOptions)
}

function markActive(state, type) {
  let {from, $from, to, empty} = state.selection
  if (empty) return type.isInSet(state.storedMarks || $from.marks())
  else return state.doc.rangeHasMark(from, to, type)
}

function markItem(markType, options) {
  let passedOptions = {
    active(state) { return markActive(state, markType) },
    enable: true
  }
  for (let prop in options) passedOptions[prop] = options[prop]
  return cmdItem(prosemirror.toggleMark(markType), passedOptions)
}

function linkItem(markType) {
  return new prosemirror.MenuItem({
    title: "Add or remove link",
    icon: prosemirror.icons.link,
    active(state) { return markActive(state, markType) },
    enable(state) { return !state.selection.empty },
    run(state, dispatch, view) {
      if (markActive(state, markType)) {
        prosemirror.toggleMark(markType)(state, dispatch)
        return true
      }
      openPrompt({
        title: I18N_CONFIG.ui.createLink,
        fields: {
          href: new TextField({
            label: I18N_CONFIG.ui.linkTarget,
            required: true
          }),
        },
        callback(attrs) {
          prosemirror.toggleMark(markType, attrs)(view.state, view.dispatch)
          view.focus()
        }
      })
    }
  })
}

function wrapListItem(nodeType, options) {
  return cmdItem(prosemirror.wrapInList(nodeType, options.attrs), options)
}

// :: (Schema) → Object
// Given a schema, look for default mark and node types in it and
// return an object with relevant menu items relating to those marks:
//
// **`toggleStrong`**`: MenuItem`
//   : A menu item to toggle the [strong mark](#schema-basic.StrongMark).
//
// **`toggleEm`**`: MenuItem`
//   : A menu item to toggle the [emphasis mark](#schema-basic.EmMark).
//
// **`toggleCode`**`: MenuItem`
//   : A menu item to toggle the [code font mark](#schema-basic.CodeMark).
//
// **`toggleLink`**`: MenuItem`
//   : A menu item to toggle the [link mark](#schema-basic.LinkMark).
//
// **`insertImage`**`: MenuItem`
//   : A menu item to insert an [image](#schema-basic.Image).
//
// **`wrapBulletList`**`: MenuItem`
//   : A menu item to wrap the selection in a [bullet list](#schema-list.BulletList).
//
// **`wrapOrderedList`**`: MenuItem`
//   : A menu item to wrap the selection in an [ordered list](#schema-list.OrderedList).
//
// **`wrapBlockQuote`**`: MenuItem`
//   : A menu item to wrap the selection in a [block quote](#schema-basic.BlockQuote).
//
// **`makeParagraph`**`: MenuItem`
//   : A menu item to set the current textblock to be a normal
//     [paragraph](#schema-basic.Paragraph).
//
// **`makeCodeBlock`**`: MenuItem`
//   : A menu item to set the current textblock to be a
//     [code block](#schema-basic.CodeBlock).
//
// **`makeHead[N]`**`: MenuItem`
//   : Where _N_ is 1 to 6. Menu items to set the current textblock to
//     be a [heading](#schema-basic.Heading) of level _N_.
//
// **`insertHorizontalRule`**`: MenuItem`
//   : A menu item to insert a horizontal rule.
//
// The return value also contains some prefabricated menu elements and
// menus, that you can use instead of composing your own menu from
// scratch:
//
// **`insertMenu`**`: Dropdown`
//   : A dropdown containing the `insertImage` and
//     `insertHorizontalRule` items.
//
// **`typeMenu`**`: Dropdown`
//   : A dropdown containing the items for making the current
//     textblock a paragraph, code block, or heading.
//
// **`fullMenu`**`: [[MenuElement]]`
//   : An array of arrays of menu elements for use as the full menu
//     for, for example the [menu bar](https://github.com/prosemirror/prosemirror-menu#user-content-menubar).
function buildMenuItems({schema, insertImageItem, footnotes, addFootnote}) {
  let r = {}, type
  if (type = schema.marks.strong)
    r.toggleStrong = markItem(type, {title: I18N_CONFIG.ui.toggleStrong, icon: prosemirror.icons.strong})
  if (type = schema.marks.em)
    r.toggleEm = markItem(type, {title: I18N_CONFIG.ui.toggleEmphasis, icon: prosemirror.icons.em})
  if (type = schema.marks.code)
    r.toggleCode = markItem(type, {title: I18N_CONFIG.ui.toggleCode, icon: prosemirror.icons.code})
  if (type = schema.marks.link)
    r.toggleLink = linkItem(type)

  if (type = schema.nodes.image)
    r.insertImage = insertImageItem(type)
  if (type = schema.nodes.bullet_list)
    r.wrapBulletList = wrapListItem(type, {
      title: I18N_CONFIG.ui.wrapBullet,
      icon: prosemirror.icons.bulletList
    })
  if (type = schema.nodes.ordered_list)
    r.wrapOrderedList = wrapListItem(type, {
      title: I18N_CONFIG.ui.wrapOrdered,
      icon: prosemirror.icons.orderedList
    })
  if (type = schema.nodes.blockquote)
    r.wrapBlockQuote = prosemirror.wrapItem(type, {
      title: I18N_CONFIG.ui.wrapBlock,
      icon: prosemirror.icons.blockquote
    })
  if (type = schema.nodes.paragraph)
    r.makeParagraph = prosemirror.blockTypeItem(type, {
      title: I18N_CONFIG.ui.changeParagraph,
      label: I18N_CONFIG.ui.plain
    })
  if (type = schema.nodes.code_block)
    r.makeCodeBlock = prosemirror.blockTypeItem(type, {
      title: I18N_CONFIG.ui.changeCode,
      label: I18N_CONFIG.ui.code
    })
  if (type = schema.nodes.heading)
    for (let i = 1; i <= 3; i++)
      r["makeHead" + i] = prosemirror.blockTypeItem(type, {
        title: I18N_CONFIG.ui.changeHeading + " " + i,
        label: I18N_CONFIG.ui.level + " " + i,
        attrs: {level: i}
      })
  if (type = schema.nodes.horizontal_rule) {
    let hr = type
    r.insertHorizontalRule = new prosemirror.MenuItem({
      title: I18N_CONFIG.ui.insertHr,
      label: I18N_CONFIG.ui.hr,
      enable(state) { return canInsert(state, hr) },
      run(state, dispatch) { dispatch(state.tr.replaceSelectionWith(hr.create())) }
    })
  }
  if (_.isFunction(addFootnote)) {
    r.addFootnote = new prosemirror.MenuItem({
      title: I18N_CONFIG.ui.addFnText,
      label: I18N_CONFIG.ui.fnText,
      run: addFootnote,
    })
  }

  let cut = arr => arr.filter(x => x)
  let footnotables = footnoteSubmenuContent(footnotes)
  function updateFootnotes(footnotes) {
    while (footnotables.length) {
      footnotables.pop()
    }
    const newFootnotables = footnoteSubmenuContent(footnotes)
    while(newFootnotables.length) {
      footnotables.push(newFootnotables.pop())
    }
  }
  r.footnoteMenu = new prosemirror.DropdownSubmenu(footnotables, {label: I18N_CONFIG.ui.fnRef})
  r.footnoteMenu.updateFootnotes = updateFootnotes
  r.insertMenu = new prosemirror.Dropdown(cut([r.insertImage, r.insertHorizontalRule, r.footnoteMenu, r.addFootnote]), {label: I18N_CONFIG.ui.insert})
  r.typeMenu = new prosemirror.Dropdown(cut([r.makeParagraph, r.makeCodeBlock, r.makeHead1 && new prosemirror.DropdownSubmenu(cut([
    r.makeHead1, r.makeHead2, r.makeHead3,
  ]), {label: I18N_CONFIG.ui.heading})]), {label: I18N_CONFIG.ui.type + I18N_CONFIG.ui.ellipsis})

  r.inlineMenu = [cut([r.toggleStrong, r.toggleEm, r.toggleCode, r.toggleLink])]
  r.blockMenu = [cut([r.wrapBulletList, r.wrapOrderedList, r.wrapBlockQuote, prosemirror.joinUpItem,
                      prosemirror.liftItem, prosemirror.selectParentNodeItem])]
  r.fullMenu = r.inlineMenu.concat([[r.insertMenu, r.typeMenu]], [[prosemirror.undoItem, prosemirror.redoItem]], r.blockMenu)

  return r
}

function footnoteSubmenuContent(footnotes) {
  return _.map(footnotes, (v, k) => {
    return new prosemirror.MenuItem({
      title: I18N_CONFIG.ui.insertFn + " " + k,
      label: I18N_CONFIG.ui.fn + " " + k,
      select(state) {
        return prosemirror.insertPoint(state.doc, state.selection.from, schema.nodes.footnote_ref) != null
      },
      run(state, dispatch) {
        let {empty, $from, $to} = state.selection, content = prosemirror.Fragment.empty
        if (!empty && $from.sameParent($to) && $from.parent.inlineContent)
          content = $from.parent.content.cut($from.parentOffset, $to.parentOffset)
        dispatch(state.tr.replaceSelectionWith(schema.nodes.footnote_ref.create({ref: k}, content)))
      }
    })
  })
}



// KEYMAP

// :: (Schema, ?Object) → Object
// Inspect the given schema looking for marks and nodes from the
// basic schema, and if found, add key bindings related to them.
// This will add:
//
// * **Mod-b** for toggling [strong](#schema-basic.StrongMark)
// * **Mod-i** for toggling [emphasis](#schema-basic.EmMark)
// * **Mod-`** for toggling [code font](#schema-basic.CodeMark)
// * **Ctrl-Shift-0** for making the current textblock a paragraph
// * **Ctrl-Shift-1** to **Ctrl-Shift-Digit6** for making the current
//   textblock a heading of the corresponding level
// * **Ctrl-Shift-Backslash** to make the current textblock a code block
// * **Ctrl-Shift-8** to wrap the selection in an ordered list
// * **Ctrl-Shift-9** to wrap the selection in a bullet list
// * **Ctrl->** to wrap the selection in a block quote
// * **Enter** to split a non-empty textblock in a list item while at
//   the same time splitting the list item
// * **Mod-Enter** to insert a hard break
// * **Mod-_** to insert a horizontal rule
// * **Backspace** to undo an input rule
// * **Alt-ArrowUp** to `joinUp`
// * **Alt-ArrowDown** to `joinDown`
// * **Mod-BracketLeft** to `lift`
// * **Escape** to `selectParentNode`
//
// You can suppress or map these bindings by passing a `mapKeys`
// argument, which maps key names (say `"Mod-B"` to either `false`, to
// remove the binding, or a new key name string.
function buildKeymap(schema, mapKeys) {
  const mac = typeof navigator != "undefined" ? /Mac/.test(navigator.platform) : false
  let keys = {}, type
  function bind(key, cmd) {
    if (mapKeys) {
      let mapped = mapKeys[key]
      if (mapped === false) return
      if (mapped) key = mapped
    }
    keys[key] = cmd
  }


  bind("Mod-z", prosemirror.undo)
  bind("Shift-Mod-z", prosemirror.redo)
  bind("Backspace", prosemirror.undoInputRule)
  if (!mac) bind("Mod-y", prosemirror.redo)

  bind("Alt-ArrowUp", prosemirror.joinUp)
  bind("Alt-ArrowDown", prosemirror.joinDown)
  bind("Mod-BracketLeft", prosemirror.lift)
  bind("Escape", prosemirror.selectParentNode)

  if (type = schema.marks.strong) {
    bind("Mod-b", prosemirror.toggleMark(type))
    bind("Mod-B", prosemirror.toggleMark(type))
  }
  if (type = schema.marks.em) {
    bind("Mod-i", prosemirror.toggleMark(type))
    bind("Mod-I", prosemirror.toggleMark(type))
  }
  if (type = schema.marks.code)
    bind("Mod-`", prosemirror.toggleMark(type))

  if (type = schema.nodes.bullet_list)
    bind("Shift-Ctrl-8", prosemirror.wrapInList(type))
  if (type = schema.nodes.ordered_list)
    bind("Shift-Ctrl-9", prosemirror.wrapInList(type))
  if (type = schema.nodes.blockquote)
    bind("Ctrl->", prosemirror.wrapIn(type))
  if (type = schema.nodes.hard_break) {
    let br = type, cmd = prosemirror.chainCommands(prosemirror.exitCode, (state, dispatch) => {
      dispatch(state.tr.replaceSelectionWith(br.create()).scrollIntoView())
      return true
    })
    bind("Mod-Enter", cmd)
    bind("Shift-Enter", cmd)
    if (mac) bind("Ctrl-Enter", cmd)
  }
  if (type = schema.nodes.list_item) {
    bind("Enter", prosemirror.splitListItem(type))
    bind("Mod-[", prosemirror.liftListItem(type))
    bind("Mod-]", prosemirror.sinkListItem(type))
  }
  if (type = schema.nodes.paragraph)
    bind("Shift-Ctrl-0", prosemirror.setBlockType(type))
  if (type = schema.nodes.code_block)
    bind("Shift-Ctrl-\\", prosemirror.setBlockType(type))
  if (type = schema.nodes.heading)
    for (let i = 1; i <= 6; i++) bind("Shift-Ctrl-" + i, prosemirror.setBlockType(type, {level: i}))
  if (type = schema.nodes.horizontal_rule) {
    let hr = type
    bind("Mod-_", (state, dispatch) => {
      dispatch(state.tr.replaceSelectionWith(hr.create()).scrollIntoView())
      return true
    })
  }

  return keys
}


// INPUTRULES

// : (NodeType) → InputRule
// Given a blockquote node type, returns an input rule that turns `"> "`
// at the start of a textblock into a blockquote.
function blockQuoteRule(nodeType) {
  return prosemirror.wrappingInputRule(/^\s*>\s$/, nodeType)
}

// : (NodeType) → InputRule
// Given a list node type, returns an input rule that turns a number
// followed by a dot at the start of a textblock into an ordered list.
function orderedListRule(nodeType) {
  return prosemirror.wrappingInputRule(/^(\d+)\.\s$/, nodeType, match => ({order: +match[1]}),
                           (match, node) => node.childCount + node.attrs.order == +match[1])
}

// : (NodeType) → InputRule
// Given a list node type, returns an input rule that turns a bullet
// (dash, plush, or asterisk) at the start of a textblock into a
// bullet list.
function bulletListRule(nodeType) {
  return prosemirror.wrappingInputRule(/^\s*([-+*])\s$/, nodeType)
}

// : (NodeType) → InputRule
// Given a code block node type, returns an input rule that turns a
// textblock starting with three backticks into a code block.
function codeBlockRule(nodeType) {
  return prosemirror.textblockTypeInputRule(/^```$/, nodeType)
}

// : (NodeType, number) → InputRule
// Given a node type and a maximum level, creates an input rule that
// turns up to that number of `#` characters followed by a space at
// the start of a textblock into a heading whose level corresponds to
// the number of `#` signs.
function headingRule(nodeType, maxLevel) {
  return prosemirror.textblockTypeInputRule(new RegExp("^(#{1," + maxLevel + "})\\s$"),
                                nodeType, match => ({level: match[1].length}))
}

// : (Schema) → Plugin
// A set of input rules for creating the basic block quotes, lists,
// code blocks, and heading.
function buildInputRules(schema) {
  let rules = prosemirror.smartQuotes.concat(prosemirror.ellipsis, prosemirror.emDash), type
  if (type = schema.nodes.blockquote) rules.push(blockQuoteRule(type))
  if (type = schema.nodes.ordered_list) rules.push(orderedListRule(type))
  if (type = schema.nodes.bullet_list) rules.push(bulletListRule(type))
  if (type = schema.nodes.code_block) rules.push(codeBlockRule(type))
  if (type = schema.nodes.heading) rules.push(headingRule(type, 6))
  return prosemirror.inputRules({rules})
}

//EXAMPLESETUP
//
//
// !! This module exports helper functions for deriving a set of basic
// menu items, input rules, or key bindings from a schema. These
// values need to know about the schema for two reasons—they need
// access to specific instances of node and mark types, and they need
// to know which of the node and mark types that they know about are
// actually present in the schema.
//
// The `exampleSetup` plugin ties these together into a plugin that
// will automatically enable this basic functionality in an editor.

// :: (Object) → [Plugin]
// A convenience plugin that bundles together a simple menu with basic
// key bindings, input rules, and styling for the example schema.
// Probably only useful for quickly setting up a passable
// editor—you'll need more control over your settings in most
// real-world situations.
//
//   options::- The following options are recognized:
//
//     schema:: Schema
//     The schema to generate key bindings and menu items for.
//
//     mapKeys:: ?Object
//     Can be used to [adjust](#example-setup.buildKeymap) the key bindings created.
//
//     menuBar:: ?bool
//     Set to false to disable the menu bar.
//
//     history:: ?bool
//     Set to false to disable the history plugin.
//
//     floatingMenu:: ?bool
//     Set to false to make the menu bar non-floating.
//
//     menuContent:: [[MenuItem]]
//     Can be used to override the menu content.
function prosemirrorView({container, uploadImage, onChange, initialState, initialMarkdownText, footnotes, addFootnote, postId}) {


  function insertImageItem(nodeType) {
    return new prosemirror.MenuItem({
      title: I18N_CONFIG.ui.insertImage,
      label: I18N_CONFIG.ui.image,
      enable(state) { return canInsert(state, nodeType) },
      run(state, _, view) {
        let {from, to} = state.selection, attrs = null
        if (state.selection instanceof prosemirror.NodeSelection && state.selection.node.type == nodeType) {
          attrs = state.selection.node.attrs
        }
        openPrompt({
          title: I18N_CONFIG.ui.insertImage,
          fields: {
            src: new FileField({label: I18N_CONFIG.ui.file, className: 'photo-input', required: true, value: attrs && attrs.src, accept: "image/*"}),
          },
          callback(attrs) {
            startImageUpload(view, attrs)
            view.focus()
          }
        })
      }
    })
  }

  function startImageUpload(view, {src, alt}) {
    // A fresh object to act as the ID for this upload
    let id = {}

    // Replace the selection with a placeholder
    let tr = view.state.tr
    if (!tr.selection.empty) {
      tr.deleteSelection()
    }
    view.dispatch(tr)
    const imageId = uuid.v4()
    const canonicalExt = canonicalImageTypes[_.toLower(src.name.split('.').pop())]
    const privateImageUrl = getImagePrivateUrl({postId, imageId, ext: canonicalExt, size: 500})
    const image = view.state.schema.nodes.image.create({
      src: privateImageUrl,
      file: src,
      size: 500,
      canonicalExt,
      postId,
      imageId,
      alt,
      title: alt,
    })
    view.dispatch(
      view.state.tr.replaceWith(tr.selection.from, tr.selection.from, image)
    )
  }

  function findNodePosition(doc, test) {
    let result = -1;
    doc.descendants((node, pos) => {
      if (test(node)) {
        result = pos;
        return false;
      }
    });
    return result;
  }

  let menuItems = buildMenuItems({schema: schema, insertImageItem, footnotes, addFootnote})
  let plugins = [
    buildInputRules(schema),
    prosemirror.keymap(buildKeymap(schema)),
    prosemirror.keymap(prosemirror.baseKeymap),
    prosemirror.dropCursor(),
    prosemirror.gapCursor(),
    prosemirror.history(),
    prosemirror.menuBar(
      {
        content: menuItems.fullMenu,
      }
    ),
  ]
  function updateFootnoteMenu({footnotes, names}) {
    menuItems = buildMenuItems({schema: schema, insertImageItem, footnotes, addFootnote})
    plugins = [
      buildInputRules(schema),
      prosemirror.keymap(buildKeymap(schema)),
      prosemirror.keymap(prosemirror.baseKeymap),
      prosemirror.dropCursor(),
      prosemirror.gapCursor(),
      prosemirror.history(),
      prosemirror.menuBar(
        {
          content: menuItems.fullMenu,
        }
      ),
    ]
    view.updateState(view.state.reconfigure({plugins}))
    _.each(names, (v, k) => {
      if ( v === k ) {
        return
      }
      let pos = findNodePosition(view.state.doc, (n) => {
        return _.get(n, 'attrs.ref') === k
      })
      while (pos !== -1) {
        if (_.isNull(k)) {
          view.dispatch(
            view.state.tr
            .setSelection(new prosemirror.NodeSelection(view.state.doc.resolve(pos)))
            .deleteSelection()
            .setMeta('addToHistory', false)
          )
        } else {
          view.dispatch(
            view.state.tr
            .setSelection(new prosemirror.NodeSelection(view.state.doc.resolve(pos)))
            .replaceSelectionWith(schema.nodes.footnote_ref.create({ref: v}, prosemirror.Fragment.empty))
            .setMeta('addToHistory', false)
          )
        }
        pos = findNodePosition(view.state.doc, (n) => {
          return _.get(n, 'attrs.ref') === k
        })
      }
    })
  }
  const initState = initialState ? prosemirror.EditorState.fromJSON(
    {
      schema: schema,
      plugins
    }, _.isString(initialState) ? JSON.parse(initialState) : initialState) : prosemirror.EditorState.create({
    doc: footnoteMarkdownParser.parse(initialMarkdownText),
    plugins,
  })
  // Load editor view
  const view = new prosemirror.EditorView(container, {
    // Set initial state
    state: initState,
    nodeViews: {
      footnote_ref(node, view, getPos) {
        return new FootnoteView(node, view, getPos)
      },
      image(node, view, getPos) {
        return new ImageView(node, view, getPos)
      }
    },
    dispatchTransaction(tr) {
      const { state } = view.state.applyTransaction(tr)
      view.updateState(state)
      if (tr.docChanged) {
        const content = footnoteMarkdownSerializer.serialize(tr.doc)
        onChange({
          editorState: serializeState(),
          content,
        }, updateFootnoteMenu)
      }
    },
  })

  function serializeState() {
    return view.state.toJSON()
  }

  return {
    view,
    plugins,
    updateFootnoteMenu,
  }
}


// Helper for iterating through the nodes in a document that changed
// compared to the given previous document. Useful for avoiding
// duplicate work on each transaction.
function changedDescendants(old, cur, offset, f) {
  let oldSize = old.childCount, curSize = cur.childCount
  outer: for (let i = 0, j = 0; i < curSize; i++) {
    let child = cur.child(i)
    for (let scan = j, e = Math.min(oldSize, i + 3); scan < e; scan++) {
      if (old.child(scan) == child) {
        j = scan + 1
        offset += child.nodeSize
        continue outer
      }
    }
    f(child, offset)
    if (j < oldSize && old.child(j).sameMarkup(child))
      changedDescendants(old.child(j), child, offset + 1, f)
    else
      child.nodesBetween(0, child.content.size, f, offset + 1)
    offset += child.nodeSize
  }
}
