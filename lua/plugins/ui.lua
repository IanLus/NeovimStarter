---@module "snacks"
---@module "bufferline"
---@module "neo-tree"
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
      window = {
        width = 30,
      },
      filesystem = {
        filtered_items = { visible = false, hide_dotfiles = false },
        follow_current_file = { enabled = true },
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
          -- position = "float", -- 默认bottom
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
  {
    "sphamba/smear-cursor.nvim",
    cond = function()
      if os.getenv("KITTY_WINDOW_ID") ~= nil or vim.g.neovide ~= nil then
        return false
      end
      return true
    end,
  },
}
