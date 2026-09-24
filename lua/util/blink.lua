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

--- Blink merges every client's trigger chars. Tailwind's `(` must not be sent to vtsls as TriggerCharacter.
local function with_client_trigger(context, client)
  local ch = context.trigger.character
  if context.trigger.kind ~= "trigger_character" or not ch then
    return context
  end
  local chars = vim.tbl_get(client, "server_capabilities", "completionProvider", "triggerCharacters") or {}
  if vim.tbl_contains(chars, ch) then
    return context
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

function M.setup()
  patch_lsp_completion()

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
