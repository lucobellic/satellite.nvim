local api = vim.api
local fn = vim.fn

---@class Satellite.Util
local M = {}

--- @generic F: function
--- @param f F
--- @param ms integer
--- @return F
function M.debounce_trailing(f, ms)
  local timer = assert(vim.uv.new_timer())
  return function(...)
    local argv = { ... }
    timer:start(ms or 100, 0, function()
      vim.schedule(function()
        timer:stop()
        f(unpack(argv))
      end)
    end)
  end
end

--- Returns the height of a window excluding the winbar
--- @param winid integer
--- @return integer
function M.get_winheight(winid)
  local winheight = api.nvim_win_get_height(winid)

  if vim.wo[winid].winbar ~= '' then
    winheight = winheight - 1
  end

  return winheight
end

--- Round to the nearest integer.
--- WARN: .5 rounds to the right on the number line, including for negatives
--- (which would not result in rounding up in magnitude).
--- (e.g., round(3.5) == 3, round(-3.5) == -3 != -4)
--- @param x number
--- @return integer
function M.round(x)
  return math.floor(x + 0.5)
end

---Scale a buffer range without rendering text outside the viewport.
---@public
--- @param winid integer
--- @param row integer First buffer row, zero based
--- @param row2 integer Last buffer row, zero based and inclusive
--- @return integer
function M.height_to_virtual(winid, row, row2)
  local line_count = api.nvim_buf_line_count(api.nvim_win_get_buf(winid))
  local winheight = math.max(1, M.get_winheight(winid))
  local height = M.round(winheight * math.max(0, row2 - row + 1) / line_count)
  return math.max(1, math.min(winheight, height))
end

---Map a buffer row to a scrollbar row using logical line positions.
---@public
--- @param winid integer
--- @param row integer Buffer row, zero based
--- @return integer, number
function M.row_to_barpos(winid, row)
  local last_row = api.nvim_buf_line_count(api.nvim_win_get_buf(winid)) - 1
  local last_bar_row = math.max(0, M.get_winheight(winid) - 1)
  local v = last_bar_row * math.max(0, math.min(last_row, row)) / math.max(1, last_row)
  local vr = M.round(v)
  return vr, vr - v
end

---Map a scrollbar row back to a buffer line without scanning the buffer.
---@public
---@param winid integer
---@param row integer Scrollbar row, zero based
---@return integer line Buffer line, one based
function M.barpos_to_line(winid, row)
  local last_row = api.nvim_buf_line_count(api.nvim_win_get_buf(winid)) - 1
  local last_bar_row = math.max(0, M.get_winheight(winid) - 1)
  local position = math.max(0, math.min(last_bar_row, row))
  return M.round(last_row * position / math.max(1, last_bar_row)) + 1
end

--- Run callback when command is run
--- @param cmd string
--- @param augroup string|integer
--- @param f function()
function M.on_cmd(cmd, augroup, f)
  api.nvim_create_autocmd('CmdlineLeave', {
    group = augroup,
    callback = function()
      if fn.getcmdtype() == ':' and vim.startswith(fn.getcmdline(), cmd) then
        f()
      end
    end,
  })
end

--- Returns true for ordinary windows (not floating and not external), and false
--- otherwise.
--- @param winid integer
--- @return boolean
function M.is_ordinary_window(winid)
  local cfg = api.nvim_win_get_config(winid)
  local not_external = not cfg['external']
  local not_floating = cfg['relative'] == ''
  return not_external and not_floating
end

--- Return top line and bottom line in window. For folds, the top line
--- represents the start of the fold and the bottom line represents the end of
--- the fold.
--- @param winid integer
--- @return integer, integer
function M.visible_line_range(winid)
  --- @diagnostic disable-next-line: missing-return-value
  -- WARN: getwininfo(winid)[1].botline is not properly updated for some
  -- movements (Neovim Issue #13510), so this is implemeneted as a workaround.
  return unpack(api.nvim_win_call(winid, function()
    local topline = fn.line('w0')
    -- line('w$') returns 0 in silent Ex mode, but line('w0') is always greater
    -- than or equal to 1.
    local botline = math.max(fn.line('w$'), topline)
    --- @diagnostic disable-next-line:redundant-return-value
    return { topline, botline }
  end))
end

--- @generic F: function
--- @param f F
--- @return F
function M.noautocmd(f)
  return function(...)
    local eventignore = vim.o.eventignore
    vim.o.eventignore = 'all'
    local r = { pcall(f, ...) }
    vim.o.eventignore = eventignore
    if not r[1] then
      error(r[2])
    end
    return unpack(r, 2, table.maxn(r))
  end
end

function M.in_cmdline_win(winid)
  winid = winid or api.nvim_get_current_win()
  if not api.nvim_win_is_valid(winid) then
    return false
  end
  if fn.win_gettype(winid) == 'command' then
    return true
  end
  local bufnr = api.nvim_win_get_buf(winid)
  return api.nvim_buf_get_name(bufnr) == '[Command Line]'
end

--- Predicate function to check whether a bufnr and winid are valid.
--- @param bufnr integer
--- @param winid? integer
--- @return fun(): false?
function M.winbuf_pred(bufnr, winid)
  local buftick = vim.b[bufnr].changedtick

  return function()
    if bufnr then
      if not api.nvim_buf_is_valid(bufnr) then
        return false
      end
      if vim.b[bufnr].changedtick ~= buftick then
        return false
      end
    end

    if winid and not api.nvim_win_is_valid(winid) then
      return false
    end
  end
end

return M
