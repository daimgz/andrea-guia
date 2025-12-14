-- UI and window management for Kanban plugin

local file_ops = require("kanban.file_ops")

local M = {}

-- Open file in floating popup
function M.open_file()
  local filename = vim.fn.expand("<cfile>")
  if filename == "" or vim.fn.filereadable(filename) ~= 1 then
    vim.notify("No valid file under cursor", vim.log.levels.WARN)
    return
  end

  local buf = vim.fn.bufadd(filename)
  vim.fn.bufload(buf)

  vim.bo[buf].buftype = ""
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = true
  vim.bo[buf].buflisted = true

  local width = math.floor(vim.o.columns * 0.6)
  local height = math.floor(vim.o.lines * 0.6)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded",
    style = "minimal",
    title = filename,
    title_pos = "center",
    zindex = 50  -- Lower z-index for floating windows to appear above
  })
  
  -- Enable line numbers
  vim.api.nvim_win_set_option(win, "number", true)
  vim.api.nvim_win_set_option(win, "relativenumber", false)
end

-- Open Kanban board
function M.kanban_open()
  -- Open in reverse order to get correct layout
  file_ops.open_or_create_with_header("DONE.md", "DONE")
  vim.cmd("vsplit")
  file_ops.open_or_create_with_header("DOING.md", "DOING")
  vim.cmd("vsplit")
  file_ops.open_or_create_with_header("TODO.md", "TODO")

  vim.cmd("wincmd h")  -- Go to first window

  vim.cmd("wincmd =")
end

-- Close Kanban splits
function M.close_kanban_splits()
  local kanban_files = { "TODO.md", "DOING.md", "DONE.md" }

  -- Collect Kanban windows
  local wins_to_close = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local buf_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
    for _, kf in ipairs(kanban_files) do
      if buf_name == kf then
        table.insert(wins_to_close, {win = win, buf = buf})
      end
    end
  end

  for _, item in ipairs(wins_to_close) do
    local wins_count = #vim.api.nvim_tabpage_list_wins(0)
    if wins_count > 1 then
      vim.api.nvim_win_close(item.win, true)
      if vim.api.nvim_buf_is_valid(item.buf) then
        vim.api.nvim_buf_delete(item.buf, {force = true})
      end
    else
      if vim.api.nvim_buf_is_valid(item.buf) then
        vim.api.nvim_buf_delete(item.buf, {force = true})
      end
      vim.cmd("enew")
    end
  end
end

return M