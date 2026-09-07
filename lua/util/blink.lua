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

function M.setup()
  if M._done then
    return
  end
  M._done = true

  local utils = require("blink.cmp.completion.brackets.utils")
  local orig_has = utils.has_brackets_in_front
  function utils.has_brackets_in_front(text_edit, bracket)
    if orig_has(text_edit, bracket) then
      return true
    end
    return already_has_args(char_after(vim.api.nvim_get_current_line(), text_edit.range["end"].character))
  end

  local brackets = require("blink.cmp.completion.brackets")
  local orig_add = brackets.add_brackets
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
