-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here
--
-- 直接打开文件时本文件会在 Snacks 就绪前加载，所以这里不用 Snacks.toggle。

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
