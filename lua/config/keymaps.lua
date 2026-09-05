-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- 关掉 LazyVim 的 Snacks 浮动终端
pcall(vim.keymap.del, { "n", "t" }, "<c-/>")

local keymap = vim.keymap
local opts = { noremap = true, silent = true }

-- 与 <leader>ft 一样出现在 which-key 的 f 组
keymap.set({ "n", "t" }, "<leader>f/", function()
  require("luxterm.core").toggle_manager()
end, vim.tbl_extend("force", opts, { desc = "Terminal (Luxterm)" }))

-- Insert a line up/down in normal mode
keymap.set("n", "O", "O<Esc>", opts)
keymap.set("n", "o", "o<Esc>", opts)

-- Insert one line below in insert mode without break current line)
keymap.set("i", "<C-CR>", "<Esc>A<CR>", opts)

-- Add the default action for <leader>+k to open the URL in win host's default browser(for wsl2)
keymap.set("n", "<leader>k", function()
  -- Get the word under the cursor (which could be a URL or keyword)
  local word = vim.fn.expand("<cfile>")
  -- 如果光标下不是 URL，可以尝试获取整个行并查找 URL
  local line = vim.fn.getline(".")
  local url = line:match("https?://[%w-_%.%?%.:/%+=&@%%]+") or word
  if url then
    -- Invoke cmd is faster than wslview command to open win host's browser
    local release = (vim.loop or vim.uv).os_uname().release:lower()
    if release:find("microsoft") ~= nil or release:find("wsl") ~= nil then
      vim.fn.system("/usr/local/bin/cmd.exe /c start " .. url:gsub(":+$", ""))
    else
      vim.fn.system("xdg-open " .. url)
    end
  else
    vim.lsp.buf.hover() -- 如果没有找到 URL，回退到 LSP 悬浮窗口
  end
end, vim.tbl_extend("force", opts, { desc = "Open the URL with default browser" }))

-- Move window
keymap.set("n", "sj", "<C-w>j", opts)
keymap.set("n", "sk", "<C-w>k", opts)
keymap.set("n", "sh", "<C-w>h", opts)
keymap.set("n", "sl", "<C-w>l", opts)

-- Resize window
keymap.set("n", "<C-w><left>", "<C-w><", opts)
keymap.set("n", "<C-w><right>", "<C-w>>", opts)
keymap.set("n", "<C-w><up>", "<C-w>+", opts)
keymap.set("n", "<C-w><down>", "<C-w>-", opts)

-- Jump next/prev word in InsertMode
keymap.set("i", "<C-f>", "<Esc>l<cmd>lua require('spider').motion('w')<CR>i", opts)
keymap.set("i", "<C-b>", "<Esc><cmd>lua require('spider').motion('b')<CR>i", opts)

-- 将视觉块选择模式映射到 <C-q>
keymap.set("n", "<C-q>", "<C-v>", opts)
keymap.set("v", "<C-q>", "<C-v>", opts)

-- 将ctrl+h映射到Backspace，以实现mini.pairs的括号匹配删除
vim.keymap.set("i", "<C-h>", "<BS>", { remap = true })
