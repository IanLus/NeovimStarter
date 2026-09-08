-- dsznajder ES7 pack (generated.code-snippets):
--   const [${2:first}, set${2/(.*)/${1:/capitalize}/}] = useState(${3:second})
-- $1 is filename; Tab goes first → second. Setter is a transform, not a tabstop.

local M = {}

function M.setup()
  local ls = require("luasnip")
  local i = ls.insert_node
  local f = ls.function_node
  local fmt = require("luasnip.extras.fmt").fmt

  local function capitalize(args)
    local name = args[1][1] or ""
    if name == "" then
      return ""
    end
    return name:sub(1, 1):upper() .. name:sub(2)
  end

  local contexts = {
    common = {
      name = "useState",
      desc = "React useState() hook",
      priority = 2000,
    },
    "useStateSnippet",
    "usestate",
    "useState",
  }

  for _, ft in ipairs({
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  }) do
    ls.add_snippets(ft, {
      ls.multi_snippet(
        contexts,
        fmt("const [{state}, set{setter}] = useState({init})", {
          state = i(1, "first"),
          setter = f(capitalize, { 1 }),
          init = i(2, "second"),
        })
      ),
    }, { key = "user-useState-" .. ft })
  end
end

return M
