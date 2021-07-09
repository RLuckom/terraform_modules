const { baseKeymap, wrapIn, setBlockType, chainCommands, toggleMark, exitCode, joinUp, joinDown, lift, selectParentNode} = require("prosemirror-commands")
const {dropCursor} = require("prosemirror-dropcursor")
const {gapCursor} = require("prosemirror-gapcursor")
const { Schema, Fragment } = require("prosemirror-model")
const {history, undo, redo} = require("prosemirror-history")
const {undoInputRule, inputRules, wrappingInputRule, textblockTypeInputRule, smartQuotes, emDash, ellipsis} = require("prosemirror-inputrules")
const {keymap} = require("prosemirror-keymap")
const {MenuBarView, menuBar, wrapItem, blockTypeItem, Dropdown, DropdownSubmenu, joinUpItem, liftItem, selectParentNodeItem, undoItem, redoItem, icons, MenuItem} = require("prosemirror-menu")
const {wrapInList, splitListItem, liftListItem, sinkListItem} = require("prosemirror-schema-list")
const { TextSelection, EditorState, Plugin, NodeSelection } = require("prosemirror-state")
const {EditorView, Decoration, DecorationSet} = require("prosemirror-view")
const {StepMap, insertPoint} = require('prosemirror-transform')
const {schema, defaultMarkdownParser, defaultMarkdownSerializer, MarkdownParser, MarkdownSerializer} = require('prosemirror-markdown')
const markdownit = require('markdown-it')

const uuid = require('uuid')
const yaml = require('js-yaml')
window.yaml = yaml 
window.uuid = uuid 
window.markdownit = markdownit
window.prosemirror = {
  Fragment, StepMap, EditorState, MenuBarView, Plugin, NodeSelection, insertPoint,  Schema, schema, MarkdownParser, MarkdownSerializer,
  EditorView, Decoration, DecorationSet, TextSelection,
  wrapInList, splitListItem, liftListItem, sinkListItem,
  menuBar, wrapItem, blockTypeItem, Dropdown, DropdownSubmenu, joinUpItem, liftItem, selectParentNodeItem, undoItem, redoItem, icons, MenuItem,
  keymap,
  undoInputRule, inputRules, wrappingInputRule, textblockTypeInputRule, smartQuotes, emDash, ellipsis,
  history, undo, redo,
  gapCursor,
  dropCursor,
  defaultMarkdownParser, defaultMarkdownSerializer, 
  toggleMark, baseKeymap, wrapIn, setBlockType, chainCommands, toggleMark, exitCode, joinUp, joinDown, lift, selectParentNode
}
