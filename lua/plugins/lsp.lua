---@module "mason"
---@module "mason-lspconfig"
---@module "lazy"
---@type LazySpec
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
        "oxfmt",
        "oxlint",
        "stylua",
        "tailwindcss",
        "ts_ls",
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
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = {
        enabled = false,
      },
      servers = {
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
