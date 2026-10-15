if vim.g.loaded_satellite then
  return
end

vim.g.loaded_satellite = true

vim.api.nvim_create_autocmd('BufWinEnter', {
  callback = function()
    -- Avoid rendering hidden text just to decide whether to load the scrollbar.
    if vim.api.nvim_buf_line_count(0) > vim.api.nvim_win_get_height(0) then
      require('satellite').setup()
    end
  end,
})
