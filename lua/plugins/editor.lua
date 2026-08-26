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
    branch = "master",
    enabled = false,
  },
  {
    "linux-cultist/venv-selector.nvim",
    ---@param opts venv-selector.Settings
    opts = function(_, opts)
      local root = vim.env.MINIFORGE or vim.env.MAMBA_ROOT_PREFIX or "C:\\Software\\miniforge3"
      root = root:gsub("/", "\\"):gsub("\\+$", "")
      opts.options = opts.options or {}
      opts.options.shell = { shell = "cmd", shellcmdflag = "/c" }
      opts.options.picker = "snacks"
      local fd = vim.fn.exepath("fd")
      if fd ~= "" then
        opts.options.fd_binary_name = fd
      end
      local project =
        '$FD Scripts\\\\python.exe$ "%s" --full-path --color never -HI -a -L --max-depth 4 -E .git -E node_modules -E .cache'
      opts.search = vim.tbl_extend("force", opts.search or {}, {
        miniconda_envs = {
          command = string.format(
            '$FD python.exe$ "%s\\envs" --no-ignore-vcs --full-path -a -E Lib --max-depth 2',
            root
          ),
          type = "anaconda",
        },
        miniconda_base = {
          command = string.format(
            '$FD python.exe$ "%s" --no-ignore-vcs --full-path -a --color never --max-depth 1',
            root
          ),
          type = "anaconda",
        },
        cwd = { command = string.format(project, "$CWD") },
        workspace = { command = string.format(project, "$WORKSPACE_PATH") },
        -- unused managers on this machine; skip empty fd jobs
        anaconda_envs = false,
        anaconda_base = false,
        hatch = false,
        poetry = false,
        pyenv = false,
        pipenv = false,
        pixi = false,
        pipx = false,
        file = false,
      })
      return opts
    end,
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
