-- Preview functionality for Kanban plugin

local config = require("kanban.config")

-- Preview state
local preview_state = {
  win = nil,
  buf = nil,
  last_file = nil,
  timer = nil,
  autocmd_group = nil
}

local M = {}

-- Check if file is text file
local function is_text_file(filename)
  local ext = filename:match("^.+(%..+)$")
  if not ext then return false end

  local text_extensions = config.get_section("preview").text_extensions
  for _, text_ext in ipairs(text_extensions) do
    if ext == text_ext then
      return true
    end
  end
  return false
end

-- Extract filename from current line
local function extract_filename_from_line(line)
  local pattern = "([%w%-%_%.%/%\\]+%.[%w]+)"
  return line:match(pattern)
end

-- Resolve filename relative to current working directory
local function resolve_filename(filename)
  local cwd = vim.fn.getcwd()
  local full_path = cwd .. "/" .. filename

  if vim.fn.filereadable(full_path) == 1 then
    return full_path
  end
  return nil
end

-- Close preview window safely
function M.close_preview_window()
  if preview_state.win and vim.api.nvim_win_is_valid(preview_state.win) then
    vim.api.nvim_win_close(preview_state.win, true)
  end
  if preview_state.buf and vim.api.nvim_buf_is_valid(preview_state.buf) then
    vim.api.nvim_buf_delete(preview_state.buf, { force = true })
  end
  preview_state.win = nil
  preview_state.buf = nil
  preview_state.last_file = nil
end

-- Update preview content
local function update_preview(filename)
  -- Validate file
  if not is_text_file(filename) then
    M.close_preview_window()
    return
  end

  local full_path = resolve_filename(filename)
  if not full_path then
    M.close_preview_window()
    return
  end

  local preview_config = config.get_section("preview")
  
  -- Check file size
  local file_size = vim.fn.getfsize(full_path)
  if file_size > preview_config.max_file_size or file_size < 0 then
    M.close_preview_window()
    return
  end

  -- Read file content
  local lines = vim.fn.readfile(full_path, "", preview_config.preview_lines)
  if #lines == 0 then
    lines = {"(Empty file)"}
  end

  -- Close existing preview window
  M.close_preview_window()

  -- Calculate floating window dimensions
  local width = vim.o.columns
  local height = preview_config.preview_lines + 2
  local row = vim.o.lines - height - 1  -- Move 1 line up
  local col = 0

  -- Create preview buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Create content with centered and colored title line
  local title_with_padding = " " .. filename .. " "
  local title_pos = math.floor((width - #title_with_padding) / 2)
  local left_fill = string.rep("─", title_pos)
  local right_fill = string.rep("─", width - title_pos - #title_with_padding)
  local title_line = left_fill .. title_with_padding .. right_fill
  
  local content = {title_line, ""}
  for _, line in ipairs(lines) do
    table.insert(content, line)
  end
  table.insert(content, "")  -- Empty line at the end

  -- Set content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

  -- Set filetype for syntax highlighting
  local ft = vim.filetype.match({ filename = full_path })
  if ft then
    vim.api.nvim_buf_set_option(buf, "filetype", ft)
  end
  
  -- Add highlighting for title line
  vim.api.nvim_buf_add_highlight(buf, -1, "Title", 0, 0, -1)

  -- Create floating window without border
  local preview_win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = "none",
    style = "minimal"
  })

  -- Enable wrap for long lines
  vim.api.nvim_win_set_option(preview_win, "wrap", true)

  -- Store state
  preview_state.win = preview_win
  preview_state.buf = buf
end

-- Debounced preview update
local function debounced_update_preview(filename)
  local preview_config = config.get_section("preview")
  
  if preview_state.timer then
    vim.fn.timer_stop(preview_state.timer)
  end

  preview_state.timer = vim.fn.timer_start(preview_config.debounce_time, function()
    update_preview(filename)
    preview_state.timer = nil
  end)
end

-- Main cursor movement handler
local function handle_cursor_moved()
  local preview_config = config.get_section("preview")
  if not preview_config.enabled then
    return
  end

  -- Don't show preview in visual or insert mode
  local mode = vim.fn.mode()
  if mode:match("[vV\22i]") then
    M.close_preview_window()
    return
  end

  -- Only work in kanban files
  local buf_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
  if not (buf_name == "TODO.md" or buf_name == "DOING.md" or buf_name == "DONE.md") then
    M.close_preview_window()
    return
  end

  local line = vim.api.nvim_get_current_line()
  local filename = extract_filename_from_line(line)

  if filename and filename ~= preview_state.last_file then
    preview_state.last_file = filename
    debounced_update_preview(filename)
  elseif not filename then
    M.close_preview_window()
    preview_state.last_file = nil
  end
end

-- Setup preview autocmds
function M.setup_preview_autocmds()
  if preview_state.autocmd_group then
    return
  end

  preview_state.autocmd_group = vim.api.nvim_create_augroup("KanbanPreview", { clear = true })

  vim.api.nvim_create_autocmd("CursorMoved", {
    group = preview_state.autocmd_group,
    pattern = {"TODO.md", "DOING.md", "DONE.md"},
    callback = handle_cursor_moved
  })

  vim.api.nvim_create_autocmd("InsertEnter", {
    group = preview_state.autocmd_group,
    pattern = {"TODO.md", "DOING.md", "DONE.md"},
    callback = M.close_preview_window
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    group = preview_state.autocmd_group,
    pattern = {"TODO.md", "DOING.md", "DONE.md"},
    callback = M.close_preview_window
  })

  vim.api.nvim_create_autocmd("InsertEnter", {
    group = preview_state.autocmd_group,
    pattern = {"todo.md", "doing.md", "done.md"},
    callback = M.close_preview_window
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    group = preview_state.autocmd_group,
    pattern = {"todo.md", "doing.md", "done.md"},
    callback = M.close_preview_window
  })
end

-- Enable preview
function M.enable_preview()
  local preview_config = config.get_section("preview")
  preview_config.enabled = true
  M.setup_preview_autocmds()
  vim.notify("Kanban preview enabled", vim.log.levels.INFO)
end

-- Disable preview
function M.disable_preview()
  local preview_config = config.get_section("preview")
  preview_config.enabled = false
  M.close_preview_window()
  if preview_state.autocmd_group then
    vim.api.nvim_clear_autocmds({ group = preview_state.autocmd_group })
    preview_state.autocmd_group = nil
  end
  vim.notify("Kanban preview disabled", vim.log.levels.INFO)
end

-- Toggle preview
function M.toggle_preview()
  local preview_config = config.get_section("preview")
  if preview_config.enabled then
    M.disable_preview()
  else
    M.enable_preview()
  end
end

return M