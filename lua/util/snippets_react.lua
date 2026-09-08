-- ES7: setter is a transform of $1, not set${2:State}. Trigger is `useState`
-- so LuaSnip does not replace stock `useStateSnippet`; both show that label.

local M = {}

local Snippet = require("blink.cmp.types").CompletionItemKind.Snippet

local ours = {
  useState = true,
  usestate = true,
  us = true,
}

function M.setup()
  local ls = require("luasnip")
  local s = ls.snippet
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

  local function make()
    return s({
      trig = "useState",
      name = "useStateSnippet",
      desc = "React useState() hook",
      priority = 2000,
    }, fmt("const [{state}, set{setter}] = useState({init})", {
      state = i(1, "first"),
      setter = f(capitalize, { 1 }),
      init = i(2, "second"),
    }))
  end

  for _, ft in ipairs({
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  }) do
    ls.add_snippets(ft, { make() }, { key = "user-useState-" .. ft })
  end
end

local function as_snippet(item)
  item.label = "useStateSnippet"
  item.kind = Snippet
  item.kind_name = "Snippet"
  return item
end

local function better(a, b)
  if not a then
    return b
  end
  return (b.sortText or "") < (a.sortText or "") and b or a
end

--- Keep our ES7 then stock, both labeled `useStateSnippet~`. LSP stays first.
function M.dedupe(items)
  local stock, our, rest = nil, nil, {}
  for _, item in ipairs(items) do
    local lab = item.label
    if lab == "useStateSnippet" then
      stock = better(stock, item)
    elseif ours[lab] then
      our = better(our, item)
    else
      rest[#rest + 1] = item
    end
  end
  if our then
    rest[#rest + 1] = as_snippet(our)
  end
  if stock then
    stock = as_snippet(stock)
    stock.score_offset = (stock.score_offset or 0) - 1
    rest[#rest + 1] = stock
  end
  return rest
end

return M
