---@module "snacks"
---@module "bufferline"
---@module "neo-tree"
---@module "blink.cmp"
---@module "ibl"
---@module "rainbow-delimiters"
---@module "lazy"
---@type LazySpec
return {
  -- neo-tree file manager sidebar
  {
    "nvim-neo-tree/neo-tree.nvim",
    version = "^3.x",
    event = "VeryLazy",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    cmd = "NeoTree",
    keys = {
      { "<leader>e", "<cmd>Neotree toggle<CR>", desc = "Toggle Neo-tree" },
    },
    ---@type neotree.Config
    opts = {
      close_if_last_window = false,
      window = {
        width = 30,
      },
      filesystem = {
        filtered_items = { visible = false, hide_dotfiles = false },
        follow_current_file = { enabled = true, leave_dirs_open = true },
        group_empty_dirs = true,
        use_libuv_file_watcher = true,
      },
    },
  },

  -- dropbar - shows symbols in the window
  {
    "Bekaboo/dropbar.nvim",
    event = "BufReadPre",
  },
  -- noice.nvim - replaces the vim ui for messages, commands and more
  {
    "folke/noice.nvim",
    opts = function(_, opts)
      table.insert(opts.routes, {
        filter = {
          event = "notify",
          find = "No information available",
        },
        opts = { skip = true },
      })
      opts.presets.lsp_doc_border = true
    end,
  },

  -- bufferline - fancy tabs
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = "nvim-tree/nvim-web-devicons",
    ---@type bufferline.UserConfig
    opts = {
      options = {
        mode = "buffers",
        show_buffer_close_icons = false,
        show_close_icon = false,
      },
    },
  },

  -- lualine - statusline
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    opts = function(_, opts)
      opts.options.theme = "catppuccin-mocha"
      table.insert(opts.sections.lualine_x, "fileformat")
      opts.sections.lualine_z = { "encoding", "filesize" }
    end,
  },

  -- incline - floating filename line
  {
    "b0o/incline.nvim",
    enabled = false,
    event = "BufReadPre",
    priority = 1200,
    config = function()
      local helpers = require("incline.helpers")
      require("incline").setup({
        window = {
          padding = 0,
          margin = { horizontal = 0 },
        },
        render = function(props)
          local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ":t")
          local ft_icon, ft_color = require("nvim-web-devicons").get_icon_color(filename)
          local modified = vim.bo[props.buf].modified
          local buffer = {
            ft_icon and { " ", ft_icon, " ", guibg = ft_color, guifg = helpers.contrast_color(ft_color) } or "",
            " ",
            { filename, gui = modified and "bold,italic" or "bold" },
            " ",
            guibg = "#363944",
          }
          return buffer
        end,
      })
    end,
  },

  -- database
  -- {
  --   "kristijanhusak/vim-dadbod-ui",
  --   dependencies = {
  --     { "tpope/vim-dadbod", lazy = true },
  --     { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
  --   },
  --   cmd = {
  --     "DBUI",
  --     "DBUIToggle",
  --     "DBUIAddConnection",
  --     "DBUIFindBuffer",
  --   },
  --   init = function()
  --     -- Your DBUI configuration
  --     vim.g.db_ui_use_nerd_fonts = 1
  --   end,
  --   keys = {
  --     {
  --       "<leader>d",
  --       "<cmd>Neotree<cr><cmd>tabnew<cr><bar><bar><cmd>DBUI<cr>",
  --       desc = "DataBaseUI",
  --     },
  --   },
  -- },

  -- snacks.nvim - collection of neovim tools
  {
    "folke/snacks.nvim",
    priority = 1000,
    ---@type snacks.Config
    opts = {
      image = { enabled = true },
      explorer = { replace_netrw = false, trash = false },
      words = { enabled = true },
      statuscolumn = {
        folds = {
          open = true, -- show open fold icons
          git_hl = true, -- use Git Signs hl for fold icons
        },
      },
      indent = { enabled = true },
      terminal = {
        win = {
          keys = {
            hide_slash = false,
            hide_underscore = false,
          },
        },
      },
      dashboard = {
        sections = {
          {
            section = "terminal",
            -- cmd = "chafa ~/.config/pic/t1.png --format symbols --symbols vhalf --size 60x20 --stretch; sleep .1",
            cmd = "chafa ~/.config/pic/rain.jpg --size 60x20 --stretch; sleep .1",
            -- cmd = "viu ~/.config/pic/rain.jpg -w 60 -h 20; sleep .1",
            height = 20,
            padding = 1,
          },
          {
            pane = 2,
            { section = "keys", gap = 1, padding = 1 },
            { section = "startup" },
          },
        },
      },
    },
  },
  -- rainbow-delimiters - rainbow colored brackets
  {
    "hiphish/rainbow-delimiters.nvim",
    submodules = false,
    ---@type rainbow_delimiters.config
    opts = {
      strategy = {
        [""] = "rainbow-delimiters.strategy.global",
        vim = "rainbow-delimiters.strategy.local",
      },
      query = {
        [""] = "rainbow-delimiters",
        lua = "rainbow-blocks",
      },
      priority = {
        [""] = 110,
        lua = 210,
      },
      highlight = {
        "RainbowDelimiterRed",
        "RainbowDelimiterYellow",
        "RainbowDelimiterBlue",
        "RainbowDelimiterOrange",
        "RainbowDelimiterGreen",
        "RainbowDelimiterViolet",
        "RainbowDelimiterCyan",
      },
    },
    main = "rainbow-delimiters.setup",
  },

  -- indent-blankline rainbow scope highlights (uses catppuccin RainbowDelimiter* groups)
  {
    "lukas-reineke/indent-blankline.nvim",
    ---@param opts ibl.config
    opts = function(_, opts)
      local highlight = {
        "RainbowDelimiterRed",
        "RainbowDelimiterYellow",
        "RainbowDelimiterBlue",
        "RainbowDelimiterOrange",
        "RainbowDelimiterGreen",
        "RainbowDelimiterViolet",
        "RainbowDelimiterCyan",
      }
      opts.scope = vim.tbl_deep_extend("force", opts.scope or {}, {
        highlight = highlight,
        show_start = true, -- restore horizontal line at scope start
      })
      return opts
    end,
    config = function(_, opts)
      local hooks = require("ibl.hooks")
      require("ibl").setup(opts)
      hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
    end,
  },
  -- blink.cmp - completion engine
  {
    "saghen/blink.cmp",
    ---@type blink.cmp.Config
    opts = {
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
                    vim.api.nvim_buf_set_lines(0, line - 1, line, false, { indent_str })
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
        -- blink/emmet have no context-aware JSX option; filter emmet outside markup.
        transform_items = function(ctx, items)
          local ft = vim.bo[ctx.bufnr].filetype
          if ft ~= "typescriptreact" and ft ~= "javascriptreact" then
            return items
          end
          local row = ctx.cursor[1] - 1
          local col = math.max((ctx.cursor[2] or 1) - 1, 0)
          local ok, node = pcall(vim.treesitter.get_node, { bufnr = ctx.bufnr, pos = { row, col } })
          local allow_emmet = false
          if ok and node then
            -- deny first: JS `{...}`, generics `<Table<IDataType>`, attributes
            local deny = {
              jsx_expression = true,
              jsx_attribute = true,
              type_arguments = true,
              type_parameters = true,
            }
            local allow = {
              jsx_element = true,
              jsx_text = true,
              jsx_opening_element = true,
              jsx_closing_element = true,
              jsx_self_closing_element = true,
              jsx_fragment = true,
              jsx_opening_fragment = true,
              jsx_closing_fragment = true,
            }
            while node do
              local t = node:type()
              if deny[t] then
                allow_emmet = false
                break
              end
              if allow[t] then
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
              local lsp_client = vim.lsp.get_client_by_id(item.client_id)
              client = lsp_client and lsp_client.name or ""
            end
            if not (item.source_id == "lsp" and tostring(client):find("emmet", 1, true)) then
              filtered[#filtered + 1] = item
            end
          end
          return filtered
        end,
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
    end,
  },
  {
    "sphamba/smear-cursor.nvim",
    cond = function()
      if os.getenv("KITTY_WINDOW_ID") ~= nil or vim.g.neovide ~= nil then
        return false
      end
      return true
    end,
  },
  {
    "luxvim/nvim-luxterm",
    pin = true,
    opts = {
      keymaps = {
        toggle_manager = "<C-/>",
        prev_session = "<C-k>",
        next_session = "<C-j>",
        hide_terminal = "<C-q>",
      },
      session_as_buffer = false,
    },
    config = function(_, opts)
      require("luxterm").setup(opts)

      -- LazyVim 在 VeryLazy 会用 Snacks.terminal 覆盖 <C-/>，需在 LazyVimKeymaps 之后重绑
      local function bind_toggle_manager()
        local key = opts.keymaps.toggle_manager
        local toggle = function()
          require("luxterm.core").toggle_manager()
        end
        local map_opts = { silent = true, desc = "Toggle Luxterm manager" }
        for _, lhs in ipairs({ "<C-/>", "<C-_>", key }) do
          pcall(vim.keymap.del, { "n", "t" }, lhs)
        end
        vim.keymap.set({ "n", "t" }, key, toggle, map_opts)
        if key == "<C-/>" then
          vim.keymap.set({ "n", "t" }, "<C-_>", toggle, { silent = true, desc = "which_key_ignore" })
        end
      end
      vim.api.nvim_create_autocmd("User", {
        pattern = "LazyVimKeymaps",
        group = vim.api.nvim_create_augroup("luxterm_keymaps", { clear = true }),
        callback = bind_toggle_manager,
      })
      if vim.v.vim_did_enter == 1 then
        vim.schedule(bind_toggle_manager)
      end

      -- 补双击 <Esc>/<C-[> → normal（上游见 floating_window.lua:345-347）
      local events = require("luxterm.events")
      local session_manager = require("luxterm.session_manager")
      local timers = {}

      local function setup_double_esc(bufnr)
        if not vim.api.nvim_buf_is_valid(bufnr) or timers[bufnr] then
          return
        end
        if not session_manager.get_session_by_buffer(bufnr) then
          return
        end

        local timer = vim.uv.new_timer()
        timers[bufnr] = timer

        local function on_escape()
          if timer:is_active() then
            timer:stop()
            vim.cmd.stopinsert()
          else
            timer:start(200, 0, function() end)
            return "<Esc>"
          end
        end

        local esc_opts = {
          buffer = bufnr,
          expr = true,
          silent = true,
          desc = "Double escape to normal mode",
        }
        vim.keymap.set("t", "<Esc>", on_escape, esc_opts)
        -- vim.keymap.set("t", "<C-[>", on_escape, esc_opts)
      end

      events.on(events.SESSION_CREATED, function(payload)
        setup_double_esc(payload.session.bufnr)
      end)

      for _, session in ipairs(session_manager.get_all_sessions()) do
        setup_double_esc(session.bufnr)
      end
    end,
  },
}
