---@module "mason"
---@module "mason-lspconfig"
---@module "lazy"
---@type LazySpec

--- neoconf 仍只挂钩 lspconfig.setup。LazyVim 用 vim.lsp.config 启动服务器，
--- 在解析配置时把 .vscode/settings.json 并进 client，并保留 lsp/*.lua 里原有的 before_init。
local function install_neoconf_lsp_hook()
  local mt = getmetatable(vim.lsp.config)
  if mt._cwe_neoconf then
    return
  end

  local applied = setmetatable({}, { __mode = "k" })
  local wrapped = setmetatable({}, { __mode = "k" })
  local index = mt.__index
  mt.__index = function(self, name)
    local resolved = index(self, name)
    if name == "*" or type(resolved) ~= "table" then
      return resolved
    end

    local current = resolved.before_init
    if type(current) == "function" and wrapped[current] then
      return resolved
    end

    local function before_init(params, config)
      local root = config.root_dir
      if type(root) == "string" and not applied[config] then
        applied[config] = true
        local ok, err = pcall(require("neoconf.plugins.lspconfig").on_new_config, config, root, config)
        if not ok then
          vim.notify_once("neoconf: " .. tostring(err), vim.log.levels.WARN)
        end
      end
      if type(current) == "function" then
        current(params, config)
      end
    end
    wrapped[before_init] = true
    resolved.before_init = before_init
    return resolved
  end
  mt._cwe_neoconf = true
end

return {
  {
    "mason-org/mason.nvim",
    ---@type MasonSettings
    opts = {
      pip = {
        upgrade_pip = false,
        install_args = { "-i", "https://pypi.tuna.tsinghua.edu.cn/simple" },
      },
      npm = {
        install_args = { "--registry", "https://registry.npmmirror.com" },
      },
      ui = {
        border = "rounded",
        backdrop = 100, -- The backdrop opacity
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
      -- formatters / linters (stylua is already in LazyVim's mason list)
      ensure_installed = { "oxfmt", "oxlint" },
    },
  },
  {
    "mason-org/mason-lspconfig.nvim",
    ---@type MasonLspconfigSettings
    opts = {
      ensure_installed = {
        "biome",
        "cssls",
        "emmet_language_server",
        "eslint",
        "html",
        "jsonls",
        "lua_ls",
        "marksman",
        "tailwindcss",
        "vtsls",
        "vue_ls",
        "bashls",
        "yamlls",
        "clangd",
        "taplo",
        "texlab",
        "pyright",
        "ruff",
        -- "dockerls",
        -- "docker_language_server",
        -- "docker_compose_language_service",
      },
      automatic_enable = true,
    },
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",
    },
  },
  {
    "folke/neoconf.nvim",
    -- LazyVim extra 用 cmd = "Neoconf" 懒加载，并且只挂钩旧的 lspconfig.setup。
    lazy = false,
    priority = 100,
    opts = {
      import = {
        vscode = true,
      },
    },
    config = function(_, opts)
      require("neoconf").setup(opts)
      install_neoconf_lsp_hook()
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = {
        enabled = false,
      },
      servers = {
        -- VS Code 默认 completeFunctionCalls = false；LazyVim 会把它打开。
        -- javascript 由 LazyVim 从 typescript 拷一份，不必再写一遍。
        vtsls = {
          settings = {
            complete_function_calls = false,
            typescript = {
              suggest = { completeFunctionCalls = false },
            },
          },
        },
        tailwindcss = {
          settings = {
            tailwindCSS = {
              classFunctions = { "cva", "cx", "cn", "clsx" },
              experimental = {
                classRegex = {
                  { "className\\s*:\\s*[\"'`]([^\"'`]+)[\"'`]" },
                  {
                    "classNames\\s*[=:]\\s*\\{([\\s\\S]*?)\\}",
                    "[`'\"`]([^'\"`;]*)[`'\"`]",
                  },
                },
              },
            },
          },
        },
        clangd = {
          -- cmd = {
          --   "clangd",
          --   "--query-driver=g++.exe", -- 指定编译器路径
          --   "--background-index",
          --   "--clang-tidy",
          --   "--completion-style=detailed",
          -- },
          init_options = {
            fallbackFlags = {
              -- "-std=c++17",
              "--target=x86_64-w64-windows-gnu",
            },
          },
        },
      },
    },
  },
}
