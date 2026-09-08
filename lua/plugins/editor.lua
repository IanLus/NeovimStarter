---@module "venv-selector"
---@module "lazy"
---@type LazySpec
return {
  {
    "chrisgrieser/nvim-spider",
    lazy = true,
    keys = {
      {
        "\\w",
        "<cmd>lua require('spider').motion('w')<CR>",
        mode = { "n", "o", "x" },
        desc = "Spider-w",
      },
      {
        "\\e",
        "<cmd>lua require('spider').motion('e')<CR>",
        mode = { "n", "o", "x" },
        desc = "Spider-e",
      },
      {
        "\\b",
        "<cmd>lua require('spider').motion('b')<CR>",
        mode = { "n", "o", "x" },
        desc = "Spider-b",
      },
    },
  },
  {
    "mg979/vim-visual-multi",
    enabled = false,
    branch = "master",
  },
  {
    "linux-cultist/venv-selector.nvim",
    ---@type venv-selector.Settings
    opts = {
      search = {
        -- Override built-in ~/miniconda3 searches for this miniforge layout:
        miniconda_envs = {
          command = "$FD 'bin/python$' ~/.config/conda/envs /opt/miniforge/envs --no-ignore-vcs --full-path --color never --max-depth 3",
          type = "anaconda",
        },
        miniconda_base = {
          command = "$FD '/python$' /opt/miniforge/bin --no-ignore-vcs --full-path --color never --max-depth 1",
          type = "anaconda",
        },
        anaconda_envs = false,
        anaconda_base = false,
      },
    },
  },
  {
    "nvim-mini/mini.pairs",
    enabled = false,
  },
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {
      -- <BS>/<C-h> 由 util.autopairs_delete 接管，避免插件 expr 映射丢掉缓冲区修改
      map_bs = false,
      map_c_h = false,
    },
    config = function(_, opts)
      require("nvim-autopairs").setup(opts)
      require("util.autopairs_delete").setup()
    end,
  },
  {
    "luxvim/nvim-luxterm",
    pin = true,
    opts = {
      keymaps = {
        toggle_manager = "<leader>f/",
        prev_session = "<C-k>",
        next_session = "<C-j>",
        hide_terminal = "<C-q>",
      },
      session_as_buffer = false,
    },
  },
}
