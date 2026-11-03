-- User patches for blink.cmp. Keep these off sources.transform_items:
-- blink re-runs that hook after path:resolve() inside a libuv callback.

local M = {}

local emmet_deny = {
  jsx_expression = true,
  jsx_attribute = true,
  type_arguments = true,
  type_parameters = true,
}

local emmet_allow = {
  jsx_element = true,
  jsx_text = true,
  jsx_opening_element = true,
  jsx_closing_element = true,
  jsx_self_closing_element = true,
  jsx_fragment = true,
  jsx_opening_fragment = true,
  jsx_closing_fragment = true,
}

local function char_after(line, col0)
  local col = col0 + 1
  while line:sub(col, col):match("[%w_]") do
    col = col + 1
  end
  return line:sub(col, col)
end

local function already_has_args(ch)
  return ch == "(" or ch == "<"
end

--- useState(${1:initialState}) / useState(initialState) -> useState
local function identifier_only(text)
  local ident = text:match("^([%w_%.]+)")
  if not ident then
    return text
  end
  local rest = text:sub(#ident + 1)
  if rest:match("^%s*%(") or rest:match("^%s*%${") or rest:match("^%s*%$%d") then
    return ident
  end
  return text
end

---@param ctx blink.cmp.Context
---@param items blink.cmp.CompletionItem[]
---@return blink.cmp.CompletionItem[]
function M.emmet_transform(ctx, items)
  if vim.in_fast_event() then
    return items
  end
  items = M.fix_jsdoc_kind(items)
  local ok_ft, ft = pcall(function()
    return vim.bo[ctx.bufnr].filetype
  end)
  if not ok_ft or (ft ~= "typescriptreact" and ft ~= "javascriptreact") then
    return items
  end

  local row = ctx.cursor[1] - 1
  local col = math.max((ctx.cursor[2] or 1) - 1, 0)
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = ctx.bufnr, pos = { row, col } })
  local allow_emmet = false
  if ok and node then
    while node do
      local t = node:type()
      if emmet_deny[t] then
        allow_emmet = false
        break
      end
      if emmet_allow[t] then
        allow_emmet = true
        break
      end
      node = node:parent()
    end
  end
  if allow_emmet then
    return items
  end

  local filtered = {}
  for _, item in ipairs(items) do
    local client = item.client_name
    if not client and item.client_id then
      local lsp = vim.lsp.get_client_by_id(item.client_id)
      client = lsp and lsp.name or ""
    end
    if not tostring(client):find("emmet", 1, true) then
      filtered[#filtered + 1] = item
    end
  end
  return filtered
end

--- vtsls 的 JSDoc 项 kind 是 Text=0。0 在转换里被丢掉，blink 空 kind 默认画成 Property。
function M.fix_jsdoc_kind(items)
  local Text = require("blink.cmp.types").CompletionItemKind.Text
  for _, item in ipairs(items) do
    if item.label == "/** */" then
      item.kind = Text
    end
  end
  return items
end

--- Ensure `<` is a TS/JS trigger so `foo<` is not treated as a buffer-word query.
function M.lsp_trigger_characters(module)
  M.setup()
  local chars = module:get_trigger_characters()
  local ft = vim.bo.filetype
  if (ft:find("typescript", 1, true) or ft:find("javascript", 1, true)) and not vim.tbl_contains(chars, "<") then
    chars[#chars + 1] = "<"
  end
  return chars
end

--- `<Foo` / `foo<T` : VS Code only shows LSP here. Buffer would dump every word as Text.
local function after_angle(ctx)
  local tr = ctx.trigger or {}
  if tr.initial_character == "<" or tr.character == "<" then
    return true
  end
  local col = ctx.cursor and ctx.cursor[2] or 0
  return (ctx.line or ""):sub(1, col):match("<%s*[%w_]*$") ~= nil
end

function M.buffer_should_show(ctx)
  if after_angle(ctx) then
    return false
  end
  return not (ctx.trigger.initial_kind == "trigger_character" and ctx.bounds.length == 0)
end

local ts_lsp = {
  vtsls = true,
  ts_ls = true,
  tsserver = true,
  ["typescript-tools"] = true,
}

local function copy_ctx(context, trigger_kind)
  local ctx = vim.tbl_extend("force", {}, context)
  ctx.trigger = vim.tbl_extend("force", context.trigger, { kind = trigger_kind, character = nil })
  return ctx
end

-- VS Code 只在单词或 TS 触发符（. " ' ` / @ < #）上自动补全；`(`, `{`, `[` 只开签名。
local pair_openers = { ["("] = true, ["{"] = true, ["["] = true }
local ts_triggers = {
  ["."] = true,
  ['"'] = true,
  ["'"] = true,
  ["`"] = true,
  ["/"] = true,
  ["@"] = true,
  ["<"] = true,
  ["#"] = true,
}

local function char_before_cursor()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  return vim.api.nvim_get_current_line():sub(col, col)
end

local function should_auto_show()
  local prev = char_before_cursor()
  return ts_triggers[prev] or prev:match("[%w_]") ~= nil
end

--- 已输入文本与当前每一项相同（忽略大小写）。Ctrl+N 选中或自动插入时不关。
local function typed_exact_items(trigger)
  local list = package.loaded["blink.cmp.completion.list"]
  if not list or list.is_explicitly_selected or list.preview_undo or not list.items or #list.items == 0 then
    return false
  end
  local keyword = trigger.context:get_keyword():lower()
  if keyword == "" then
    return false
  end
  for _, item in ipairs(list.items) do
    if identifier_only(tostring(item.insertText or item.label or "")):lower() ~= keyword then
      return false
    end
  end
  return true
end

local function ghost_text()
  return package.loaded["blink.cmp.completion.windows.ghost_text"]
end

--- context 已被置空时 hide() 不会清幽灵文本，需要直接关掉列表和 extmark。
local function force_dismiss(trigger)
  local list = package.loaded["blink.cmp.completion.list"]
  local menu = package.loaded["blink.cmp.completion.windows.menu"]
  local ghost = ghost_text()
  local pending = trigger.context
    or (menu and menu.win:is_open())
    or (ghost and ghost.is_open())
    or (list and list.items and #list.items > 0)
  if not pending then
    return
  end
  list = require("blink.cmp.completion.list")
  list.undo_preview()
  if trigger.context then
    trigger.hide()
  else
    list.hide()
  end
  ghost = ghost_text()
  if ghost and ghost.is_open() then
    ghost.clear_preview()
  end
end

local function previewing()
  local list = package.loaded["blink.cmp.completion.list"]
  return list ~= nil and list.preview_undo ~= nil
end

local function dismiss_lingering(trigger)
  if vim.api.nvim_get_mode().mode:sub(1, 1) ~= "i" then
    return
  end
  if trigger.context and trigger.context.trigger.initial_kind == "manual" then
    return
  end
  -- 选中项的预览（例如 JSDoc 的 /** */）会把光标移出单词。
  -- 这时关掉菜单，下一项就切不过去。
  if previewing() then
    return
  end
  if not trigger.context or not should_auto_show() or typed_exact_items(trigger) then
    force_dismiss(trigger)
  end
end

function M.hide_if_after_opener()
  if pair_openers[char_before_cursor()] then
    force_dismiss(require("blink.cmp.completion.trigger"))
  end
end

--- Blink 合并各 client 触发符；tailwind 的 `(` 不能当 vtsls 的 TriggerCharacter。
---@return blink.cmp.Context|nil
local function with_client_trigger(context, client)
  local ch = context.trigger.character
  if context.trigger.kind ~= "trigger_character" or not ch then
    return context
  end
  local chars = vim.tbl_get(client, "server_capabilities", "completionProvider", "triggerCharacters") or {}
  if vim.tbl_contains(chars, ch) then
    return context
  end
  if pair_openers[ch] then
    return nil
  end
  return copy_ctx(context, "keyword")
end

local function empty_response(response)
  return not response or not response.items or #response.items == 0
end

local function mark_incomplete_if_empty(response)
  if not empty_response(response) then
    return response
  end
  return { items = {}, is_incomplete_forward = true, is_incomplete_backward = true }
end

local function patch_lsp_completion()
  if M._lsp_done then
    return
  end
  M._lsp_done = true

  local cache = require("blink.cmp.sources.lsp.cache")
  local orig_set = cache.set
  ---@diagnostic disable-next-line: duplicate-set-field
  function cache.set(context, client, response)
    -- `[ <` is parsed as comparison and comes back []. Caching that blocks `<S`,
    -- which tsserver treats as JSX (VS Code re-queries). Same for other `<` triggers.
    if empty_response(response) and after_angle(context) then
      return
    end
    return orig_set(context, client, response)
  end

  local completion = require("blink.cmp.sources.lsp.completion")
  local orig_get = completion.get_completion_for_client
  ---@diagnostic disable-next-line: duplicate-set-field
  function completion.get_completion_for_client(context, client, opts)
    local ctx = with_client_trigger(context, client)
    if not ctx then
      return require("blink.cmp.lib.async").task.new(function(resolve)
        resolve(mark_incomplete_if_empty(nil))
      end)
    end
    local task = orig_get(ctx, client, opts)
    if not ts_lsp[client.name] then
      return task
    end
    -- Bare `<` is often empty (array JSX / generics). Invoked matches <C-Space>.
    if ctx.trigger.character == "<" and not ctx._angle_retried then
      task = task:map(function(response)
        if not empty_response(response) then
          return response
        end
        local retry = copy_ctx(ctx, "manual")
        retry._angle_retried = true
        return orig_get(retry, client, opts)
      end)
    end
    if after_angle(ctx) then
      return task:map(mark_incomplete_if_empty)
    end
    return task
  end
end

local function patch_pair_openers()
  if M._pair_done then
    return
  end
  M._pair_done = true

  local trigger = require("blink.cmp.completion.trigger")
  local orig_is = trigger.is_trigger_character
  ---@diagnostic disable-next-line: duplicate-set-field
  function trigger.is_trigger_character(char, is_show_on_x)
    if pair_openers[char] then
      return false
    end
    return orig_is(char, is_show_on_x)
  end

  local orig_show = trigger.show
  ---@diagnostic disable-next-line: duplicate-set-field
  function trigger.show(opts)
    opts = opts or {}
    if opts.trigger_kind == "manual" then
      return orig_show(opts)
    end
    -- should_auto_show() 读的是 buffer 光标。命令行里经常为假
    local mode = vim.api.nvim_get_mode().mode
    if mode == "c" or vim.fn.win_gettype() == "command" then
      return orig_show(opts)
    end
    if previewing() then
      return orig_show(opts)
    end
    if pair_openers[opts.trigger_character] or not should_auto_show() then
      force_dismiss(trigger)
      return
    end
    return orig_show(opts)
  end

  -- 延后到字符落地再关窗口，InsertCharPre 里关会 E565。
  local group = vim.api.nvim_create_augroup("blink_vscode_signature", { clear = true })
  vim.api.nvim_create_autocmd({ "TextChangedI", "CursorMovedI" }, {
    group = group,
    callback = function()
      vim.schedule(function()
        dismiss_lingering(trigger)
      end)
    end,
  })
end

local function item_filter_text(item)
  local text = item.filterText
  if type(text) ~= "string" or text == "" then
    text = item.label or ""
  end
  return text:match('^"(.*)"$') or text:match("^'(.*)'$") or text
end

local function typed_keyword()
  local ok, keyword = pcall(function()
    return require("blink.cmp.completion.trigger.context").get_keyword()
  end)
  if not ok or type(keyword) ~= "string" then
    return ""
  end
  return keyword
end

--- LSP CompletionItemTag.Deprecated
local function is_deprecated(item)
  if item.deprecated then
    return true
  end
  if type(item.tags) ~= "table" then
    return false
  end
  for _, tag in ipairs(item.tags) do
    if tag == 1 then
      return true
    end
  end
  return false
end

--- 已弃用的项沉底。VS Code 不让 deprecated 靠分数挤到前面。
function M.sort_deprecated_last(a, b)
  local ad, bd = is_deprecated(a), is_deprecated(b)
  if ad ~= bd then
    return not ad
  end
end

--- 整词命中（忽略大小写）先于只命中前缀的项。
--- blink 的 exact 区分大小写，"ge" 对不上 "GE"，snippet "get" 会靠大小写加分排到字面量前面。
function M.sort_whole_word_first(a, b)
  local keyword = typed_keyword()
  if keyword == "" then
    return
  end
  local kw = keyword:lower()
  local function whole(item)
    return item_filter_text(item):lower() == kw
  end
  local aw, bw = whole(a), whole(b)
  if aw ~= bw then
    return aw
  end
end

local image_exts = {
  png = true,
  jpg = true,
  jpeg = true,
  gif = true,
  webp = true,
  bmp = true,
  tiff = true,
  svg = true,
}

local px_cache = {}

local function is_image_path(path)
  local ext = vim.fn.fnamemodify(path, ":e"):lower()
  return image_exts[ext] == true and vim.fn.filereadable(path) == 1
end

--- 把像素尺寸收进文档窗的最大宽高，保持比例。
local function fit_cells(px_w, px_h, max_w, max_h)
  local term = require("snacks.image.terminal").size()
  local cw = math.max(term.cell_width or 10, 1)
  local ch = math.max(term.cell_height or 20, 1)
  local cols = math.max(1, math.ceil(px_w / cw))
  local rows = math.max(1, math.ceil(px_h / ch))
  if cols > max_w or rows > max_h then
    local scale = math.min(max_w / cols, max_h / rows)
    cols = math.max(1, math.floor(cols * scale + 0.5))
    rows = math.max(1, math.floor(rows * scale + 0.5))
  end
  return cols, rows
end

---@param path string
---@param cb fun(w?: integer, h?: integer)
local function read_pixels(path, cb)
  local cached = px_cache[path]
  if cached then
    cb(cached[1], cached[2])
    return
  end
  local ext = vim.fn.fnamemodify(path, ":e"):lower()
  if ext == "png" then
    local ok, dim = pcall(require("snacks.image.util").dim, path)
    if ok and dim and dim.width and dim.height then
      px_cache[path] = { dim.width, dim.height }
      cb(dim.width, dim.height)
      return
    end
  end
  if ext == "svg" then
    local fd = io.open(path, "r")
    if fd then
      local head = fd:read(800) or ""
      fd:close()
      local w = tonumber(head:match('width="([%d%.]+)'))
      local h = tonumber(head:match('height="([%d%.]+)'))
      if w and h and w > 0 and h > 0 and w <= 4096 and h <= 4096 then
        px_cache[path] = { w, h }
        cb(w, h)
        return
      end
    end
  end
  if vim.fn.executable("ffprobe") ~= 1 then
    cb()
    return
  end
  vim.system({
    "ffprobe",
    "-v",
    "error",
    "-select_streams",
    "v:0",
    "-show_entries",
    "stream=width,height",
    "-of",
    "csv=p=0:s=x",
    path,
  }, { text = true }, function(obj)
    vim.schedule(function()
      local w, h = (obj.stdout or ""):match("(%d+)x(%d+)")
      w, h = tonumber(w), tonumber(h)
      if obj.code == 0 and w and h then
        px_cache[path] = { w, h }
        cb(w, h)
      else
        cb()
      end
    end)
  end)
end

---@param opts blink.cmp.CompletionDocumentationDrawOpts
---@param path string
---@param px_w? integer
---@param px_h? integer
local function draw_image_docs(opts, path, px_w, px_h)
  local buf = opts.window:get_buf()
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local max_w = opts.config.window.max_width or 80
  local max_h = opts.config.window.max_height or 20
  local cols, rows
  if px_w and px_h and px_w > 0 and px_h > 0 then
    cols, rows = fit_cells(px_w, px_h, max_w, max_h)
  else
    cols, rows = math.min(48, max_w), math.min(14, max_h)
  end
  local line = string.rep(" ", cols)
  local lines = {}
  for _ = 1, rows do
    lines[#lines + 1] = line
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  local token = vim.b[buf].path_image_token
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(buf) or vim.b[buf].path_image_token ~= token then
      return
    end
    local win = opts.window:get_win()
    if win and vim.api.nvim_win_is_valid(win) then
      vim.wo[win].wrap = false
    end
    pcall(function()
      require("snacks.image").buf.attach(buf, {
        src = path,
        width = cols,
        height = rows,
        max_width = cols,
        max_height = rows,
      })
    end)
  end)
end

--- 路径补全：文本仍走原来的内容预览，图片改在同一个文档窗里显示。
---@param self table
---@param item blink.cmp.CompletionItem
---@param callback fun(item: blink.cmp.CompletionItem)
function M.path_resolve(self, item, callback)
  local full = item.data and item.data.full_path
  if type(full) ~= "string" or not is_image_path(full) then
    return self:resolve(item, callback)
  end
  read_pixels(full, function(w, h)
    item.documentation = {
      kind = "markdown",
      value = " ",
      ---@diagnostic disable-next-line: inject-field
      image = { path = full, w = w, h = h },
    }
    callback(item)
  end)
end

local function set_wrap(opts, wrap)
  opts.window.config.wrap = wrap
  local win = opts.window:get_win()
  if win and vim.api.nvim_win_is_valid(win) then
    vim.wo[win].wrap = wrap
  end
end

--- 文档窗绘制。上一张图的 placement 要先清掉，否则切到文本文件时图还留着。
---@param opts blink.cmp.CompletionDocumentationDrawOpts
function M.draw_docs(opts)
  local buf = opts.window and opts.window:get_buf()
  local image = opts.item and type(opts.item.documentation) == "table" and opts.item.documentation.image or nil
  if type(image) == "table" and type(image.path) == "string" then
    local selected
    local ok_list, list = pcall(require, "blink.cmp.completion.list")
    if ok_list then
      selected = list.get_selected_item()
    end
    local selected_path = selected and selected.data and selected.data.full_path
    -- ffprobe 回来时选中项可能已经换成别的文件，不要盖掉当前预览。
    if selected and selected_path ~= image.path then
      return
    end
  end
  if buf and vim.api.nvim_buf_is_valid(buf) then
    -- 让还没画上的上一张图作废。文档窗是复用的。
    vim.b[buf].path_image_token = (vim.b[buf].path_image_token or 0) + 1
  end
  local placement = package.loaded["snacks.image.placement"]
  if buf and placement then
    pcall(placement.clean, buf)
  end
  if type(image) == "table" and type(image.path) == "string" then
    -- 空格行用来撑开窗口。wrap 开着时，行宽等于窗口宽会被折成两行。
    set_wrap(opts, false)
    draw_image_docs(opts, image.path, image.w, image.h)
    return
  end
  if buf and vim.bo[buf].filetype == "image" then
    vim.bo[buf].filetype = "blink-cmp-documentation"
  end
  set_wrap(opts, true)
  opts.default_implementation()
end

function M.setup()
  patch_lsp_completion()
  patch_pair_openers()

  if M._done then
    return
  end
  M._done = true

  local utils = require("blink.cmp.completion.brackets.utils")
  local orig_has = utils.has_brackets_in_front
  ---@diagnostic disable-next-line: duplicate-set-field
  function utils.has_brackets_in_front(text_edit, bracket)
    if orig_has(text_edit, bracket) then
      return true
    end
    return already_has_args(char_after(vim.api.nvim_get_current_line(), text_edit.range["end"].character))
  end

  local brackets = require("blink.cmp.completion.brackets")
  local orig_add = brackets.add_brackets
  ---@diagnostic disable-next-line: duplicate-set-field
  function brackets.add_brackets(ctx, filetype, item)
    local te = item.textEdit
    if te and already_has_args(char_after(vim.api.nvim_get_current_line(), te.range["end"].character)) then
      local stripped = identifier_only(te.newText)
      if stripped ~= te.newText then
        te.newText = stripped
        item.insertText = stripped
        item.insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText
      end
    end
    return orig_add(ctx, filetype, item)
  end

  local orig_semantic = brackets.add_brackets_via_semantic_token
  ---@diagnostic disable-next-line: duplicate-set-field
  function brackets.add_brackets_via_semantic_token(ctx, filetype, item)
    if already_has_args(char_after(vim.api.nvim_get_current_line(), vim.api.nvim_win_get_cursor(0)[2])) then
      return require("blink.cmp.lib.async").task.new(function(resolve)
        resolve(false)
      end)
    end
    return orig_semantic(ctx, filetype, item)
  end
end

return M
