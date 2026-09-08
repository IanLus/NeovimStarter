---@module "blink.cmp"
---@module "lazy"
---@type LazySpec
return {
  {
    "L3MON4D3/LuaSnip",
    config = function(_, opts)
      require("luasnip").setup(opts)
      require("util.snippets_react").setup()
    end,
  },
  {
    "saghen/blink.cmp",
    ---@type blink.cmp.Config
    opts = {
      -- Default floor(#kw/4) typos lets `count` match `const`; VSCode does not.
      fuzzy = { max_typos = 0 },
      completion = {
        menu = {
          border = "rounded",
          draw = {
            columns = { { "label", "label_description", gap = 1 }, { "kind_icon", "kind", gap = 1 } },
            components = {
              kind_icon = {
                text = function(ctx)
                  local kind_icon, _, _ = require("mini.icons").get("lsp", ctx.kind)
                  return kind_icon
                end,
                highlight = function(ctx)
                  local _, hl, _ = require("mini.icons").get("lsp", ctx.kind)
                  return hl
                end,
              },
              kind = {
                highlight = function(ctx)
                  local _, hl, _ = require("mini.icons").get("lsp", ctx.kind)
                  return hl
                end,
              },
            },
          },
        },
        documentation = { window = { border = "rounded" } },
      },
      -- merged with LazyVim: { preset = "enter", ["<C-y>"] = ... }
      keymap = {
        ["<A-i>"] = { "show", "show_documentation", "hide_documentation" },
        ["<Tab>"] = {
          function(cmp)
            if not cmp.is_visible() then
              local line = vim.fn.line(".")
              local col = vim.fn.col(".")
              local cur_line = vim.fn.getline(line)
              local cur_indent = #cur_line:match("^%s*")
              local ok, target_indent = pcall(function()
                return require("nvim-treesitter.indent").get_indent(line)
              end)
              if ok and target_indent and target_indent >= 0 and cur_indent < target_indent then
                if col <= cur_indent + 1 or cur_line:match("^%s*$") then
                  vim.schedule(function()
                    local indent_str = vim.bo.expandtab and string.rep(" ", target_indent)
                      or string.rep("\t", math.floor(target_indent / vim.fn.shiftwidth()))
                    -- Replace only leading whitespace so content after the cursor is kept.
                    vim.api.nvim_buf_set_text(0, line - 1, 0, line - 1, cur_indent, { indent_str })
                    vim.api.nvim_win_set_cursor(0, { line, #indent_str })
                  end)
                  return true
                end
              end
            end
            if cmp.snippet_active() then
              return cmp.accept()
            else
              return cmp.select_and_accept()
            end
          end,
          "snippet_forward",
          "fallback",
        },
      },
      sources = {
        providers = {
          lsp = {
            transform_items = function(...)
              return require("util.blink").emmet_transform(...)
            end,
          },
          snippets = {
            transform_items = function(_, items)
              return require("util.snippets_react").dedupe(items)
            end,
          },
        },
      },
    },
    -- highlights are not blink opts; use init (do not set config — LazyVim owns setup)
    init = function()
      local function clear_cmp_bg()
        vim.api.nvim_set_hl(0, "Pmenu", { bg = "none" })
        vim.api.nvim_set_hl(0, "BlinkCmpMenu", { bg = "none" })
        vim.api.nvim_set_hl(0, "BlinkCmpMenuBorder", { bg = "none" })
      end
      clear_cmp_bg()
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("blink_cmp_transparent", { clear = true }),
        callback = clear_cmp_bg,
      })
      vim.api.nvim_create_autocmd("InsertEnter", {
        group = vim.api.nvim_create_augroup("user_blink_setup", { clear = true }),
        once = true,
        callback = function()
          require("util.blink").setup()
        end,
      })
    end,
  },
}
