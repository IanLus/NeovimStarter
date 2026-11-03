-- hover 正文保持原样换行。图片另开一个悬浮窗，不改 hover 的高度和边框。

local M = {}

---@type table<integer, integer> hover 窗口 -> 预览窗口
local preview_by_hover = {}

---@param buf integer
---@return integer?
local function float_win(buf)
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative ~= "" then
      return win
    end
  end
end

---@param buf integer
---@return boolean
local function is_hover_buf(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  if float_win(buf) then
    return true
  end
  return vim.bo[buf].buftype == "nofile" and vim.api.nvim_buf_get_name(buf) == ""
end

---@param win integer
---@return integer
local function outer_win(win)
  local cfg = vim.api.nvim_win_get_config(win)
  if cfg.relative == "win" and cfg.win and vim.api.nvim_win_is_valid(cfg.win) then
    return cfg.win
  end
  return win
end

---@param pwin integer
local function close_win(pwin)
  if not pwin or not vim.api.nvim_win_is_valid(pwin) then
    return
  end
  local buf = vim.api.nvim_win_get_buf(pwin)
  pcall(vim.api.nvim_win_close, pwin, true)
  if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "image" then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
end

---@param hover_win integer
function M.close(hover_win)
  local pwin = preview_by_hover[hover_win]
  preview_by_hover[hover_win] = nil
  close_win(pwin)
end

---@param text string
---@return string? path
---@return integer? px_w
---@return integer? px_h
local function write_data_image(text)
  local mime, b64 = text:match("data:(image/[%w+]+);base64,([A-Za-z0-9+/=]+)")
  if not (mime and b64 and vim.base64) then
    return
  end
  local ok, raw = pcall(vim.base64.decode, b64)
  if not ok or type(raw) ~= "string" or raw == "" then
    return
  end
  local ext = mime:match("^image/(%w+)") or "png"
  local root = vim.fn.stdpath("cache") .. "/snacks/image"
  vim.fn.mkdir(root, "p")
  local path = ("%s/%s-hover.%s"):format(root, vim.fn.sha256(raw):sub(1, 16), ext)
  if vim.fn.filereadable(path) == 0 then
    local fd = assert(io.open(path, "wb"))
    fd:write(raw)
    fd:close()
  end
  local px_w = tonumber(raw:match('width="([%d%.]+)'))
  local px_h = tonumber(raw:match('height="([%d%.]+)'))
  return path, px_w, px_h
end

---@param px_w? number
---@param px_h? number
---@return integer cols
---@return integer rows
local function cell_size(px_w, px_h)
  local term = require("snacks.image.terminal").size()
  local cw = math.max(term.cell_width or 10, 1)
  local ch = math.max(term.cell_height or 18, 1)
  local cols = math.ceil((px_w or 128) / cw)
  local rows = math.ceil((px_h or 128) / ch)
  cols = math.min(math.max(cols, 4), 36)
  rows = math.min(math.max(rows, 2), 24)
  return cols, rows
end

---@param hover_win integer
---@param cols integer
---@param rows integer
---@return vim.api.keyset.win_config
local function preview_config(hover_win, cols, rows)
  local anchor = outer_win(hover_win)
  local pos = vim.api.nvim_win_get_position(anchor)
  local anchor_w = vim.api.nvim_win_get_width(anchor)
  local z = (vim.api.nvim_win_get_config(anchor).zindex or 45) + 1
  -- 原先右侧空 2 格、左侧空 3 格，收成大约 1/3。
  local col = pos[2] + anchor_w + 1
  if col + cols + 2 > vim.o.columns then
    col = pos[2] - cols - 1
  end
  if col < 0 then
    col = 0
  end
  local row = pos[1]
  if row + rows + 2 > vim.o.lines then
    row = math.max(0, vim.o.lines - rows - 2)
  end
  return {
    relative = "editor",
    row = row,
    col = col,
    width = cols,
    height = rows,
    focusable = false,
    style = "minimal",
    border = "rounded",
    zindex = z,
  }
end

---@param buf integer
function M.show(buf)
  if not is_hover_buf(buf) then
    return
  end
  local hover_win = float_win(buf)
  if not hover_win then
    return
  end
  local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
  local path, px_w, px_h = write_data_image(text)
  if not path then
    M.close(hover_win)
    return
  end
  M.close(hover_win)
  local cols, rows = cell_size(px_w, px_h)
  local pbuf = vim.api.nvim_create_buf(false, true)
  local pwin = vim.api.nvim_open_win(pbuf, false, preview_config(hover_win, cols, rows))
  preview_by_hover[hover_win] = pwin
  pcall(function()
    require("snacks.image").buf.attach(pbuf, {
      src = path,
      width = cols,
      height = rows,
      max_width = cols,
      max_height = rows,
    })
  end)
end

function M.on_win_closed(win)
  if preview_by_hover[win] then
    M.close(win)
    return
  end
  for hover_win, pwin in pairs(preview_by_hover) do
    if pwin == win or not vim.api.nvim_win_is_valid(hover_win) then
      M.close(hover_win)
    end
  end
end

return M
