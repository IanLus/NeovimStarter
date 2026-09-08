-- Pair-aware deletes for <C-w>/<C-u>/<BS>/<C-h>.
-- Non-expr maps: nvim-autopairs expr mappings would discard buffer edits.

local M = {}

local function chars(s)
  return vim.fn.split(s, [[\zs]])
end

local function is_keyword(ch)
  return vim.fn.match(ch, [[\k]]) == 0
end

local function byte_len(s, i)
  local b = s:byte(i)
  if not b or b < 128 then
    return 1
  elseif b < 224 then
    return 2
  elseif b < 240 then
    return 3
  end
  return 4
end

--- 0-based byte start of the range <C-w> would delete.
local function word_start(line, col)
  if col <= 0 then
    return 0
  end

  local parts = chars(line:sub(1, col))
  local i = #parts
  local function space(idx)
    return parts[idx]:match("^%s+$") ~= nil
  end

  if space(i) then
    while i > 0 and space(i) do
      i = i - 1
    end
  end
  if i == 0 then
    return 0
  end

  local keyword = is_keyword(parts[i])
  while i > 0 and not space(i) and is_keyword(parts[i]) == keyword do
    i = i - 1
  end
  if i == 0 then
    return 0
  end
  return #table.concat(parts, "", 1, i)
end

local function buf_pairs()
  local npairs = package.loaded["nvim-autopairs"]
  if not npairs then
    return {}
  end
  local rules = npairs.get_buf_rules and npairs.get_buf_rules() or {}
  if vim.tbl_isempty(rules) and npairs.config then
    rules = npairs.config.rules
  end

  local opens = {}
  for _, rule in pairs(rules or {}) do
    local open, close = rule.start_pair, rule.end_pair
    if open and close and not rule.is_regex and not rule.is_endwise and not open:match("^%s+$") then
      opens[#opens + 1] = { open, close, #open, #close }
    end
  end
  table.sort(opens, function(a, b)
    return a[3] > b[3]
  end)
  return opens
end

local function opener_at_end(text, opens)
  for _, p in ipairs(opens) do
    if #text >= p[3] and text:sub(-p[3]) == p[1] then
      return p
    end
  end
end

--- Longest open/close token starting at byte `i`, or nil.
local function longest_token(s, i, opens)
  local best
  local n = #s
  for _, p in ipairs(opens) do
    local sl, el = p[3], p[4]
    if i + sl - 1 <= n and s:sub(i, i + sl - 1) == p[1] then
      local kind = p[1] == p[2] and "quote" or "open"
      if not best or sl > best.len then
        best = { kind = kind, p = p, len = sl }
      end
    end
    if p[1] ~= p[2] and i + el - 1 <= n and s:sub(i, i + el - 1) == p[2] then
      if not best or el > best.len then
        best = { kind = "close", p = p, len = el }
      end
    end
  end
  return best
end

--- 1-based byte index of the matching closer in `right`, or nil.
local function matching_close(right, open, close)
  if open == close then
    return right:find(close, 1, true)
  end
  local sl, el, depth, i, n = #open, #close, 1, 1, #right
  while i <= n do
    if i + sl - 1 <= n and right:sub(i, i + sl - 1) == open then
      depth = depth + 1
      i = i + sl
    elseif i + el - 1 <= n and right:sub(i, i + el - 1) == close then
      if depth == 1 then
        return i
      end
      depth = depth - 1
      i = i + el
    else
      i = i + byte_len(right, i)
    end
  end
end

--- Unmatched openers in `deleted` (stack top is innermost).
local function unmatched_opens(deleted, opens)
  local stack = {}
  local i, n = 1, #deleted
  while i <= n do
    local tok = longest_token(deleted, i, opens)
    if not tok then
      i = i + byte_len(deleted, i)
    else
      local top = stack[#stack]
      if tok.kind == "quote" then
        if top and top[1] == tok.p[1] then
          stack[#stack] = nil
        else
          stack[#stack + 1] = tok.p
        end
      elseif tok.kind == "close" then
        if top and top[2] == tok.p[2] then
          stack[#stack] = nil
        end
      else
        stack[#stack + 1] = tok.p
      end
      i = i + tok.len
    end
  end
  return stack
end

local function strip_matching_closers(deleted, right, opens)
  local stack = unmatched_opens(deleted, opens)
  for i = #stack, 1, -1 do
    local p = stack[i]
    local at = matching_close(right, p[1], p[2])
    if not at then
      break
    end
    right = right:sub(1, at - 1) .. right:sub(at + p[4])
  end
  return right
end

local function delete_range(start_col)
  local buf = vim.api.nvim_get_current_buf()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  if start_col >= col then
    return
  end

  local line = vim.api.nvim_get_current_line()
  local new_right = strip_matching_closers(line:sub(start_col + 1, col), line:sub(col + 1), buf_pairs())
  vim.api.nvim_buf_set_text(buf, row - 1, start_col, row - 1, #line, { new_right })
  vim.api.nvim_win_set_cursor(0, { row, start_col })
end

function M.delete_word()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  delete_range(word_start(vim.api.nvim_get_current_line(), col))
end

function M.delete_line()
  delete_range(0)
end

function M.backspace()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  if col == 0 then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<BS>", true, false, true), "n", false)
    return
  end

  local line = vim.api.nvim_get_current_line()
  local left, right = line:sub(1, col), line:sub(col + 1)
  local opens = buf_pairs()

  -- `( |x )` : drop the padding space before the closer too.
  if left:sub(-1) == " " then
    local p = opener_at_end(left:sub(1, -2), opens)
    if p then
      local at = matching_close(right, p[1], p[2])
      if at and at > 1 and right:sub(at - 1, at - 1) == " " then
        vim.api.nvim_buf_set_text(0, row - 1, col + at - 2, row - 1, col + at - 1, { "" })
        vim.api.nvim_buf_set_text(0, row - 1, col - 1, row - 1, col, { "" })
        vim.api.nvim_win_set_cursor(0, { row, col - 1 })
        return
      end
    end
  end

  local p = opener_at_end(left, opens)
  if p then
    delete_range(col - p[3])
    return
  end

  local parts = chars(left)
  local last = parts[#parts]
  local start = col - #last
  vim.api.nvim_buf_set_text(0, row - 1, start, row - 1, col, { "" })
  vim.api.nvim_win_set_cursor(0, { row, start })
end

function M.setup()
  vim.keymap.set("i", "<C-w>", M.delete_word, { desc = "Delete word and matching pairs" })
  vim.keymap.set("i", "<C-u>", M.delete_line, { desc = "Delete to line start and matching pairs" })
  vim.keymap.set("i", "<BS>", M.backspace, { desc = "Delete char and matching pair" })
  vim.keymap.set("i", "<C-h>", M.backspace, { desc = "Delete char and matching pair" })
end

return M
