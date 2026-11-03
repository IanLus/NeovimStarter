-- Snacks 的图片管线默认要 magick/identify。没有它时，png 直接交给 Kitty，
-- 其它格式先用 ffmpeg / rsvg-convert 转成 png。

local M = {}

local cache_dir = vim.fn.stdpath("cache") .. "/snacks/image-raster"
local convert_patched = false
local doc_patched = false

local function has_magick()
  return vim.fn.executable("magick") == 1 or vim.fn.executable("identify") == 1
end

---@param file string
---@param on_done? fun(convert: table)
local function done_convert(file, on_done)
  local convert = {
    file = file,
    meta = {},
  }
  function convert:done()
    return true
  end
  function convert:error()
    return nil
  end
  function convert:run()
    if on_done then
      on_done(self)
    end
  end
  return convert
end

---@param src string
---@return string?
local function rasterize(src)
  local ext = vim.fn.fnamemodify(src, ":e"):lower()
  if ext == "png" then
    return src
  end
  vim.fn.mkdir(cache_dir, "p")
  local png = ("%s/%s.png"):format(cache_dir, vim.fn.sha256(src):sub(1, 16))
  local result
  if ext == "svg" then
    -- 声明了小尺寸的 svg（antd 图标是 50）按原尺寸光栅化。
    -- VS Code 的 hover 图用图片固有大小，不再放大。
    local head = ""
    local fd = io.open(src, "r")
    if fd then
      head = fd:read(500) or ""
      fd:close()
    end
    local w = tonumber(head:match('width="([%d%.]+)'))
    local h = tonumber(head:match('height="([%d%.]+)'))
    if w and h and w > 0 and h > 0 and w <= 256 and h <= 256 then
      png = ("%s/%s-%dx%d.png"):format(cache_dir, vim.fn.sha256(src):sub(1, 16), math.ceil(w), math.ceil(h))
    end
    if vim.fn.filereadable(png) == 1 then
      return png
    end
    local cmd = { "rsvg-convert" }
    if w and h and w > 0 and h > 0 and w <= 256 and h <= 256 then
      vim.list_extend(cmd, { "-w", tostring(math.ceil(w)), "-h", tostring(math.ceil(h)) })
    else
      vim.list_extend(cmd, { "-w", "1600" })
    end
    vim.list_extend(cmd, { "-o", png, src })
    result = vim.system(cmd):wait()
  elseif vim.fn.filereadable(png) == 1 then
    return png
  elseif vim.fn.executable("ffmpeg") == 1 then
    result = vim.system({ "ffmpeg", "-y", "-v", "error", "-i", src, "-frames:v", "1", png }):wait()
  end
  if result and result.code == 0 and vim.fn.filereadable(png) == 1 then
    return png
  end
end

--- Dashboard 占位，并用 Kitty 协议画一张图，不用 chafa 字符画。
---@param path string
---@param height? number
---@param width? number
function M.dashboard_image(path, height, width)
  height = height or 20
  width = width or 60
  return {
    text = ("\n"):rep(height - 1),
    padding = 1,
    render = function(dash, pos)
      M.setup()
      local src = vim.fn.expand(path)
      local buf = vim.api.nvim_create_buf(false, true)
      local win = vim.api.nvim_open_win(buf, false, {
        bufpos = { pos[1] - 1, pos[2] + 1 },
        col = 0,
        focusable = false,
        height = height,
        noautocmd = true,
        relative = "win",
        row = 0,
        style = "minimal",
        width = width,
        border = "none",
        win = dash.win,
        zindex = ((Snacks.config.styles.dashboard or {}).zindex or 40) + 1,
      })
      local ok = pcall(function()
        require("snacks.image").buf.attach(buf, {
          src = src,
          max_width = width,
          max_height = height,
        })
      end)
      local function close()
        pcall(vim.api.nvim_win_close, win, true)
        if vim.api.nvim_buf_is_valid(buf) then
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
        return true
      end
      if not ok then
        close()
        return
      end
      dash.on("UpdatePre", close, dash.augroup)
      dash.on("Closed", close, dash.augroup)
    end,
  }
end

local function patch_data_uri()
  if doc_patched then
    return
  end
  local ok, doc = pcall(require, "snacks.image.doc")
  if not ok then
    return
  end
  doc_patched = true

  -- https://github.com/folke/snacks.nvim/issues/2668
  -- ^data:%w+/%w+;base64, 和 ^image/(%w+)$ 都吃不下 svg+xml 里的 +。
  -- 于是 data URI 不会走进 data_img，扩展名还会落成 png。
  -- https://github.com/folke/snacks.nvim/issues/2669
  -- content_id 只用 base64 前 20 个字符，不同 svg 会撞成同一张图。
  local strict_data = "^data:%w+/%w+;base64,"
  local wide_data = "^data:%w+/[%w+]+;base64,"

  local orig_data = doc.transforms.data_img
  doc.transforms.data_img = function(img, ctx)
    local src = img.src
    if type(src) == "string" and src:find("+", 1, true) and vim.base64 then
      local mime, data = src:match("^data:(.-);base64,(.+)$")
      if mime and data then
        local ok_dec, raw = pcall(vim.base64.decode, data)
        if ok_dec and type(raw) == "string" and raw ~= "" then
          img.content = raw
          img.src = nil
          -- image/svg+xml -> svg。%w+ 停在 + 前面。
          img.ext = mime:match("^image/(%w+)") or "svg"
          img.content_id = vim.fn.sha256(raw):sub(1, 16)
          return
        end
      end
    end
    orig_data(img, ctx)
    if type(img.content) == "string" and img.content ~= "" then
      img.content_id = vim.fn.sha256(img.content):sub(1, 16)
    end
  end

  local orig_img = doc._img
  function doc._img(ctx)
    local raw_src
    if ctx.src and ctx.src.node then
      local ok_text, text = pcall(vim.treesitter.get_node_text, ctx.src.node, ctx.buf, { metadata = ctx.src.meta })
      if ok_text then
        raw_src = text
      end
    end
    local img = orig_img(ctx)
    if not img or type(raw_src) ~= "string" then
      return img
    end
    -- 内置判断对不上 svg+xml，orig 不会调用 data_img。这里补上，并写成 .svg。
    if raw_src:find(wide_data) and not raw_src:find(strict_data) then
      img.src = raw_src
      img.content = nil
      doc.transforms.data_img(img, ctx)
      if img.content and not img.src then
        local root = require("snacks.image").config.cache
        vim.fn.mkdir(root, "p")
        img.src = ("%s/%s-content.%s"):format(
          root,
          img.content_id or vim.fn.sha256(img.content):sub(1, 16),
          img.ext or "svg"
        )
        if vim.fn.filereadable(img.src) == 0 then
          local fd = assert(io.open(img.src, "wb"))
          fd:write(img.content)
          fd:close()
        end
      end
    end
    return img
  end
end

local function patch_convert()
  if convert_patched or has_magick() then
    convert_patched = true
    return
  end
  local ok, convert = pcall(require, "snacks.image.convert")
  if not ok then
    return
  end
  convert_patched = true
  local orig = convert.convert
  function convert.convert(opts)
    local src = opts and opts.src
    if type(src) == "string" and not src:find("^%w%w+://") and vim.fn.filereadable(src) == 1 then
      local png = rasterize(src)
      if png then
        return done_convert(png, opts.on_done)
      end
    end
    return orig(opts)
  end
end

local function allow_svg()
  local ok, image = pcall(require, "snacks.image")
  if not ok or type(image.config.formats) ~= "table" then
    return
  end
  if not vim.tbl_contains(image.config.formats, "svg") then
    table.insert(image.config.formats, "svg")
  end
end

function M.setup()
  patch_convert()
  patch_data_uri()
  allow_svg()
end

return M
