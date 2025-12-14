-- autocmds.lua - Migrated autocmds from vimrc
local api, fn = vim.api, vim.fn

-- Restore last cursor position when opening a file
api.nvim_create_autocmd('BufReadPost', {
  callback = function()
    local mark = api.nvim_buf_get_mark(0, '"')
    local lcount = api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(api.nvim_win_set_cursor, 0, { mark[1], mark[2] })
    end
  end,
})

-- Write ShaDa on leaving a buffer (similar to :wshada)
api.nvim_create_autocmd('BufLeave', {
  callback = function()
    pcall(vim.cmd, 'wshada')
  end,
})

-- Enable Signify if available on VimEnter
--api.nvim_create_autocmd('VimEnter', {
  --callback = function()
    --if fn.exists(':SignifyEnable') == 2 then
      --pcall(vim.cmd, 'SignifyEnable')
    --end
  --end,
--})

-- Quitar espacios finales
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  command = "%s/\\s\\+$//e",
})

-- Relative line numbers (test)
--local num_group = vim.api.nvim_create_augroup("NumberToggle", { clear = true })
--vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "InsertLeave", "WinEnter" }, {
  --group = num_group,
  --callback = function()
    --if vim.wo.nu and vim.api.nvim_get_mode().mode ~= "i" then
      --vim.wo.relativenumber = true
    --end
  --end,
--})

--vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost", "InsertEnter", "WinLeave" }, {
  --group = num_group,
  --callback = function()
    --if vim.wo.nu then
      --vim.wo.relativenumber = false
    --end
  --end,
--})

-- Auto compile packer
--vim.api.nvim_create_autocmd("BufWritePost", {
  --pattern = { "init.lua", "lua/**/*.lua" },
  --command = "source <afile> | LazySync",
--})

-- Create parent directories on save
vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function(event)
    local dir = vim.fn.fnamemodify(event.match, ":p:h")
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, "p")
    end
  end,
})

-- Check for external file changes
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
  command = "checktime",
})

