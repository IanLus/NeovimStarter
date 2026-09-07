-- <C-w>/<C-u> also drop matching closers, same onion-peel as <BS>.
-- Unmatched text on the right is left alone.

local M = {}

local function is_keyword(ch)
  return vim.fn.match(ch, [[\k]]) == 0
end

--- 0-based byte start of the range <C-w> would delete.
local function word_start(line, col)
  if col <= 0 then
    return 0
  end

  local chars = vim.fn.split(line:sub(1, col), [[\zs]])
  local i = #chars
  local function space(idx)
    return chars[idx]:match("^%s+$") ~= nil
  end

  if space(i) then
    while i > 0 and space(i) do
      i = i - 1
    end
  end
  if i == 0 then
    return 0
  end

  local keyword = is_keyword(chars[i])
  while i > 0 and not space(i) and is_keyword(chars[i]) == keyword do
    i = i - 1
  end
  if i == 0 then
    return 0
  end
  return #table.concat(chars, "", 1, i)
end

local function closer_bytes(deleted, right, rules)
  local opens = {}
  for _, rule in pairs(rules) do
    if rule.start_pair and rule.end_pair and not rule.is_regex then
      opens[#opens + 1] = { rule.start_pair, rule.end_pair, #rule.start_pair, #rule.end_pair }
    end
  end
  table.sort(opens, function(a, b)
    return a[3] > b[3]
  end)

  local i, j = #deleted, 0
  while i > 0 do
    local matched = false
    for _, p in ipairs(opens) do
      local open, close, sl, el = p[1], p[2], p[3], p[4]
      if i >= sl and deleted:sub(i - sl + 1, i) == open and right:sub(j + 1, j + el) == close then
        i, j, matched = i - sl, j + el, true
        break
      end
    end
    if not matched then
      break
    end
  end
  return j
end

local function delete_range(start_col)
  local buf = vim.api.nvim_get_current_buf()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  if start_col >= col then
    return
  end

  local line = vim.api.nvim_get_current_line()
  local extra = 0
  local npairs = package.loaded["nvim-autopairs"]
  if npairs and npairs.get_buf_rules then
    extra = closer_bytes(line:sub(start_col + 1, col), line:sub(col + 1), npairs.get_buf_rules(buf))
  end

  vim.api.nvim_buf_set_text(buf, row - 1, start_col, row - 1, col + extra, { "" })
  vim.api.nvim_win_set_cursor(0, { row, start_col })
end

function M.delete_word()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  delete_range(word_start(vim.api.nvim_get_current_line(), col))
end

function M.delete_line()
  delete_range(0)
end

function M.setup()
  vim.keymap.set("i", "<C-w>", M.delete_word, { desc = "Delete word and matching pairs" })
  vim.keymap.set("i", "<C-u>", M.delete_line, { desc = "Delete to line start and matching pairs" })
end

return M
