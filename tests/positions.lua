-- Run with nvim --headless -u NONE -l tests/positions.lua from the repository root.
vim.opt.rtp:prepend(vim.fn.getcwd())

local config = require 'satellite.config'
local util = require 'satellite.util'
local view = require 'satellite.view'
local winid = vim.api.nvim_get_current_win()
local bufnr = vim.api.nvim_get_current_buf()

config.apply {
  current_only = true,
  handlers = {
    cursor = { enable = false },
    diagnostic = { enable = false },
    gitsigns = { enable = false },
    marks = { enable = false },
    quickfix = { enable = false },
    search = { enable = false },
  },
}

---@param ... any
vim.api.nvim_win_text_height = function(...)
  error('Scrollbar positioning must not measure rendered text')
end

---@param line_count integer
local function set_lines(line_count)
  vim.api.nvim_buf_set_lines(
    bufnr,
    0,
    -1,
    false,
    vim.fn['repeat']({ string.rep('text ', 40) }, line_count)
  )
  vim.cmd 'redraw'
end

---@param line_count integer
local function check_positions(line_count)
  local last_bar_row = util.get_winheight(winid) - 1
  assert(util.row_to_barpos(winid, 0) == 0)
  assert(util.barpos_to_line(winid, 0) == 1)
  assert(util.barpos_to_line(winid, last_bar_row) == line_count)
  assert(util.row_to_barpos(winid, line_count - 1) == (line_count > 1 and last_bar_row or 0))
  assert(util.row_to_barpos(winid, -1) == 0)
  assert(util.row_to_barpos(winid, line_count + 100) <= last_bar_row)
  assert(util.height_to_virtual(winid, 0, line_count - 1) == last_bar_row + 1)
  for row = 0, last_bar_row do
    local line = util.barpos_to_line(winid, row)
    assert(line >= 1 and line <= line_count)
    if line_count >= last_bar_row + 1 then
      assert(util.row_to_barpos(winid, line - 1) == row)
    end
  end
end

for _, line_count in ipairs { 1, 2, 16000 } do
  set_lines(line_count)
  check_positions(line_count)
end

vim.wo.wrap = true
vim.wo.foldmethod = 'manual'
vim.cmd '2,100fold'
local namespace = vim.api.nvim_create_namespace 'satellite-position-test'
vim.api.nvim_buf_set_extmark(bufnr, namespace, 0, 0, {
  virt_lines = { { { 'virtual line', 'Normal' } } },
})
check_positions(16000)

view.enable()
local props = assert(view.get_props(winid), 'Large buffers must still have a scrollbar')
assert(props.height >= 1)
assert(props.row + props.height <= util.get_winheight(winid))

vim.cmd 'normal! G'
vim.cmd 'redraw'
view.refresh_bars()
props = assert(view.get_props(winid))
assert(props.row + props.height <= util.get_winheight(winid))

vim.o.lines = 40
vim.o.columns = 100
vim.cmd 'redraw'
check_positions(16000)
set_lines(16001)
check_positions(16001)
view.refresh_bars()
assert(view.get_props(winid))
view.disable()
assert(view.get_props(winid) == nil)

print(
  'Scrollbar positions, large buffers, folds, wrapping, virtual lines, resize, and edits passed'
)
