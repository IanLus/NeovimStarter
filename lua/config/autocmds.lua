-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here
--
-- 直接打开文件时本文件会在 Snacks 就绪前加载，所以这里不用 Snacks.toggle。
-- 本文件在 VeryLazy 加载，此时 Snacks 已经 setup。
require("util.snacks_image").setup()

-- LazyVim wrap_spell 会给 markdown 开 spell。本文件在它之后加载，只关拼写，保留 wrap。
-- <leader>ud 默认切全局诊断；markdown 里改成只切当前 buffer。
local function toggle_buf_diagnostics()
  local buf = vim.api.nvim_get_current_buf()
  local enabled = vim.diagnostic.is_enabled({ bufnr = buf })
  vim.diagnostic.enable(not enabled, { bufnr = buf })
  if Snacks then
    Snacks.notify((enabled and "Disabled" or "Enabled") .. " **Diagnostics**", {
      title = "Diagnostics",
      level = enabled and vim.log.levels.WARN or vim.log.levels.INFO,
    })
  end
end

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("user_markdown", { clear = true }),
  pattern = { "markdown", "markdown.mdx" },
  callback = function(ev)
    vim.opt_local.spell = false
    vim.diagnostic.enable(false, { bufnr = ev.buf })
    vim.keymap.set("n", "<leader>ud", toggle_buf_diagnostics, {
      buffer = ev.buf,
      desc = "Toggle Diagnostics",
    })
  end,
})

-- hover 旁边单开预览窗显示图片，hover 自身不动。
vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
  group = vim.api.nvim_create_augroup("user_hover_image", { clear = true }),
  callback = function(ev)
    local ok, mod = pcall(require, "util.hover_image")
    if not ok or not mod.is_float_buf(ev.buf) then
      return
    end
    vim.schedule(function()
      mod.show(ev.buf)
    end)
  end,
})

vim.api.nvim_create_autocmd("WinClosed", {
  group = vim.api.nvim_create_augroup("user_hover_image_close", { clear = true }),
  callback = function(ev)
    local win = tonumber(ev.match)
    if win then
      require("util.hover_image").on_win_closed(win)
    end
  end,
})
