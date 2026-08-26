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
    opts = {},
  },
}
