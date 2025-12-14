-- File operations for Kanban plugin

local M = {}

-- Open or create file with header
function M.open_or_create_with_header(file, header)
  -- Check if buffer already exists
  local existing_buf = vim.fn.bufnr(file, false)
  if existing_buf ~= -1 then
    -- Switch to existing buffer silently
    vim.cmd("buffer " .. existing_buf)
    return
  end

  if vim.fn.filereadable(file) == 1 then
    -- Force edit without any prompts
    vim.cmd("silent! edit! " .. file)
  else
    vim.cmd("enew")
    local buf = vim.api.nvim_get_current_buf()
    vim.cmd("file " .. file)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "# " .. header, "" })
  end
end

-- Create new file from selection or input
function M.create_new_file()
  local mode = vim.fn.mode()
  local filename = nil
  local original_text = nil
  local start_line = nil
  local end_line = nil

  -- Check if we're in visual mode
  if mode:match("[vV\22]") then
    -- Get visual selection boundaries
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")

    start_line = start_pos[2]
    end_line = end_pos[2]

    if start_line == end_line then
      -- Single line selection
      -- Get exact visual selection using yank
      vim.cmd('normal! y')
      original_text = vim.fn.getreg('"')
      -- Trim whitespace and remove any extra characters
      original_text = original_text:match("^%s*(.-)%s*$")
      -- Remove potential quote characters
      original_text = original_text:gsub('^["\']', ''):gsub('["\']$', '')
    else
      -- Multi-line selection - cancel and show message
      vim.cmd("normal! <Esc>")
      vim.notify("Error: Only single line selection is allowed", vim.log.levels.ERROR)
      return
    end

    filename = original_text
  else
    -- Normal mode - ask for filename
    filename = vim.fn.input("Nuevo archivo: ")
  end

  if not filename or filename == "" then
    print("Cancelado.")
    return
  end

  -- Trim whitespace
  filename = filename:match("^%s*(.-)%s*$")

  -- Add .md if no extension
  if not filename:match("%.%w+$") then
    filename = filename .. ".md"
  end

  -- Replace spaces with underscores
  filename = filename:gsub(" ", "_")

  -- Cancel if already exists
  if vim.fn.filereadable(filename) == 1 then
    vim.notify("Error: File already exists", vim.log.levels.ERROR)
    return
  end

  -- Create directories if needed
  local dir = vim.fn.fnamemodify(filename, ":h")
  if dir ~= "" and vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end

  -- Create empty file
  vim.fn.writefile({}, filename)

  vim.notify("Created: " .. filename, vim.log.levels.INFO)

  -- Update selected text in visual mode to show new filename
  if mode:match("[vV\22]") and original_text and start_line then
    -- Replace the selected text with filename using API
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local start_line_api = start_pos[2] - 1  -- 0-indexed for API
    local start_col = start_pos[3] - 1  -- 0-indexed for API
    local end_col = end_pos[3]          -- end_pos is already inclusive

    local lines = vim.api.nvim_buf_get_lines(0, start_line_api, start_line_api + 1, false)
    if lines and lines[1] then
      local line = lines[1]
      local new_line = line:sub(1, start_col) .. filename .. line:sub(end_col + 1)
      vim.api.nvim_buf_set_lines(0, start_line_api, start_line_api + 1, false, {new_line})
    end
  else
    -- Normal mode - insert in current file (the column)
    local row = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(0, row, row, false, { filename })
  end
end

-- Rename file under cursor
function M.rename_file_under_cursor()
  local name = vim.fn.expand("<cfile>")
  if name == "" then
    vim.notify("No valid file under cursor", vim.log.levels.WARN)
    return
  end

  local cwd = vim.fn.getcwd()
  local old_path = cwd .. "/" .. name

  if vim.fn.filereadable(old_path) ~= 1 then
    vim.notify("File not found: " .. old_path, vim.log.levels.ERROR)
    return
  end

  -- Show name with spaces for better readability
  local display_name = name:gsub("_", " ")
  local new_name = vim.fn.input("Renombrar a: ", display_name)
  if new_name == "" or new_name == display_name then
    vim.notify("Rename cancelled", vim.log.levels.INFO)
    return
  end

  -- Convert spaces to underscores for actual filename
  local actual_new_name = new_name:gsub(" ", "_")
  local new_path = cwd .. "/" .. actual_new_name

  -- Rename file on disk
  if vim.fn.rename(old_path, new_path) ~= 0 then
    vim.notify("Error renaming file", vim.log.levels.ERROR)
    return
  end

  -- Update buffer if open
  local buf = vim.fn.bufnr(old_path, false)
  if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_set_name(buf, new_path)
  end

  -- Update Kanban line
  local kanban_line = vim.fn.getline(".")
  local new_kanban_line = kanban_line:gsub(vim.pesc(name), actual_new_name, 1)
  vim.api.nvim_set_current_line(new_kanban_line)

  -- Update content inside file (only if file exists and has content)
  local file_buf = vim.fn.bufnr(new_path)
  if file_buf == -1 then
    file_buf = vim.fn.bufadd(new_path)
    vim.fn.bufload(file_buf)
  end

  -- Only replace content if file has lines and contains the old name
  local lines = vim.api.nvim_buf_get_lines(file_buf, 0, -1, false)
  if lines and #lines > 0 then
    local replaced = false
    for i, l in ipairs(lines) do
      if not replaced and l:find(name, 1, true) then
        lines[i] = l:gsub(name, actual_new_name, 1)
        replaced = true
      end
    end
    if replaced then
      vim.api.nvim_buf_set_lines(file_buf, 0, -1, false, lines)
    end
  end

  -- Only write if buffer has content or was modified
  if #lines > 0 or vim.api.nvim_buf_get_option(file_buf, "modified") then
    vim.api.nvim_buf_call(file_buf, function()
      vim.cmd("write!")
    end)
  end

  vim.notify("File renamed: " .. name .. " → " .. actual_new_name, vim.log.levels.INFO)
end

-- Delete file under cursor with confirmation
function M.delete_file_under_cursor()
  local filename = vim.fn.expand("<cfile>")
  if filename == "" then
    vim.notify("No valid file under cursor", vim.log.levels.WARN)
    return
  end

  local cwd = vim.fn.getcwd()
  local file_path = cwd .. "/" .. filename

  if vim.fn.filereadable(file_path) ~= 1 then
    vim.notify("File not found: " .. filename, vim.log.levels.ERROR)
    return
  end

  -- Ask for confirmation
  local choice = vim.fn.confirm("Are you sure you want to delete '" .. filename .. "'?", "&Yes\n&No", 2)
  if choice ~= 1 then
    vim.notify("Deletion cancelled", vim.log.levels.INFO)
    return
  end

  -- Close buffer if open
  local buf = vim.fn.bufnr(file_path, false)
  if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end

  -- Delete file from disk
  if vim.fn.delete(file_path) ~= 0 then
    vim.notify("Error deleting file: " .. filename, vim.log.levels.ERROR)
    return
  end

  -- Remove from Kanban line
  local line = vim.api.nvim_get_current_line()
  local new_line = line:gsub(vim.pesc(filename), "", 1)
  new_line = new_line:gsub("%s+$", "")
  vim.api.nvim_set_current_line(new_line)

  vim.notify("File deleted: " .. filename, vim.log.levels.INFO)
end

return M
