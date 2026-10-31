-- wrap 关掉后，noice 只按文本行算高度，图被画在窗口外。
-- 内容窗和边框必须一起走 nui 的 update_layout，边框字符才会重画到新高度。
-- 只改窗口高度的话，下边框还停在原来那一行，会被预览图盖住。

local M = {}

local patched = false
--- 已经创建的 placement，用来把高度钉在图片本身，避免它跟着窗口又变高一截。
---@type table<integer, table[]>
local placements = {}

function M.install()
  if patched then
    return
  end
  local ok, placement = pcall(require, "snacks.image.placement")
  if not ok then
    return
  end
  patched = true
  local orig = placement.new
  function placement.new(buf, src, opts)
    local rows = vim.b[buf].hover_image_rows
    if type(rows) == "number" and rows > 0 then
      opts = vim.tbl_extend("force", opts or {}, {
        height = rows,
        max_height = rows,
      })
    end
    local created = orig(buf, src, opts)
    placements[buf] = placements[buf] or {}
    placements[buf][#placements[buf] + 1] = created
    return created
  end
end

---@param buf integer
---@return integer?
local function float_win(buf)
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative ~= "" then
      return win
    end
  end
end

--- hover 是无名 nofile。普通 markdown 文件不处理。
---@param buf integer
---@return boolean
local function is_hover_buf(buf)
  if float_win(buf) then
    return true
  end
  return vim.bo[buf].buftype == "nofile" and vim.api.nvim_buf_get_name(buf) == ""
end

---@param buf integer
---@return table?
local function nui_popup(buf, win)
  local ok, View = pcall(require, "noice.view")
  if not ok then
    return
  end
  for _, item in ipairs(View._views or {}) do
    local popup = item.view and item.view._nui
    if popup and popup.winid and vim.api.nvim_win_is_valid(popup.winid) then
      if popup.bufnr == buf or popup.winid == win then
        return popup
      end
    end
  end
end

---@param text string
---@return integer
local function image_rows(text)
  local px_h = 64
  local b64 = text:match("data:image/svg%+xml;base64,([A-Za-z0-9+/=]+)")
    or text:match("data:image/svg;base64,([A-Za-z0-9+/=]+)")
  if b64 and vim.base64 then
    local ok, raw = pcall(vim.base64.decode, b64)
    if ok and type(raw) == "string" then
      local h = tonumber(raw:match('height="([%d%.]+)'))
      if h and h > 0 and h <= 128 then
        px_h = h
      end
    end
  end
  local term = require("snacks.image.terminal").size()
  local cell_h = math.max(term.cell_height or 18, 1)
  local max_h = math.max(3, math.floor(350 / cell_h))
  return math.min(math.max(1, math.ceil(px_h / cell_h)), max_h)
end

---@param buf integer
---@param rows integer
local function pin(buf, rows)
  local list = placements[buf]
  if not list then
    return
  end
  for i = #list, 1, -1 do
    local p = list[i]
    if p.closed or not p.opts then
      table.remove(list, i)
    elseif p.opts.height ~= rows then
      p.opts.height = rows
      p.opts.max_height = rows
      pcall(p.update, p)
    end
  end
end

--- 只改高度。宽度沿用当前内容窗，避免边框和内容错位。
---@param buf integer
---@param win integer
---@param height integer
---@return boolean
local function set_height(buf, win, height)
  local popup = nui_popup(buf, win)
  if not popup or not popup.update_layout then
    return false
  end
  local width = vim.api.nvim_win_get_width(win)
  return pcall(popup.update_layout, popup, {
    size = { width = width, height = height },
  })
end

--- FileType 当下就把行数记上，snacks 创建 placement 时才能用这个高度，而不是窗口高度。
---@param buf integer
function M.prepare(buf)
  M.install()
  if not vim.api.nvim_buf_is_valid(buf) or not is_hover_buf(buf) then
    return
  end
  local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
  if not text:find("data:image/", 1, true) then
    return
  end
  vim.b[buf].hover_image_rows = image_rows(text)
end

---@param buf integer
function M.grow(buf)
  M.install()
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local win = float_win(buf)
  if not win then
    return
  end
  local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
  local lines = math.max(vim.api.nvim_buf_line_count(buf), 1)
  if not text:find("data:image/", 1, true) then
    if vim.b[buf].hover_image_rows and vim.api.nvim_win_get_height(win) ~= lines then
      if set_height(buf, win, lines) then
        vim.b[buf].hover_image_rows = nil
      end
    end
    return
  end

  local rows = image_rows(text)
  -- 图片画在文本下面，再留一行，避免贴住下边框。
  local height = math.min(lines + rows + 1, math.max(lines + 1, vim.o.lines - 2))
  rows = height - lines - 1
  if rows < 1 then
    return
  end
  vim.b[buf].hover_image_rows = rows
  pin(buf, rows)
  if vim.api.nvim_win_get_height(win) == height then
    return
  end
  set_height(buf, win, height)
end

return M
