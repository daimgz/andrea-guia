-- Kanban plugin for Neovim
-- Provides a simple Kanban board with file management and preview functionality

-- ==================== CONFIGURATION ====================

local M = {}
-- TODO: hacer que cuando se guarde un archivo se guarden todos
-- TODO: Poner opcion en config para que se guarde solo el archivo de kanban al cerrar

-- Preview configuration
local preview_config = {
  enabled = true,
  preview_lines = 3,
  debounce_time = 200,
  max_file_size = 50 * 1024,  -- 50KB
  text_extensions = {".md", ".txt", ".lua", ".py", ".js", ".ts", ".json", ".yaml", ".yml", ".toml", ".sh", ".zsh"}
}

-- Preview state
local preview_state = {
  win = nil,
  buf = nil,
  last_file = nil,
  timer = nil,
  autocmd_group = nil
}

-- ==================== HELPER FUNCTIONS ====================

-- Check if file is text file
local function is_text_file(filename)
  local ext = filename:match("^.+(%..+)$")
  if not ext then return false end

  for _, text_ext in ipairs(preview_config.text_extensions) do
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

-- ==================== PREVIEW FUNCTIONS ====================

-- Close preview window safely
local function close_preview_window()
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
    close_preview_window()
    return
  end

  local full_path = resolve_filename(filename)
  if not full_path then
    close_preview_window()
    return
  end

  -- Check file size
  local file_size = vim.fn.getfsize(full_path)
  if file_size > preview_config.max_file_size or file_size < 0 then
    close_preview_window()
    return
  end

  -- Read file content
  local lines = vim.fn.readfile(full_path, "", preview_config.preview_lines)
  if #lines == 0 then
    lines = {"(Empty file)"}
  end

  -- Close existing preview window
  close_preview_window()

  -- Calculate floating window dimensions
  local width = vim.o.columns
  local height = preview_config.preview_lines + 2
  local row = vim.o.lines - height
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
    style = "minimal",
    focusable = false,  -- Preview should not be focusable
    zindex = 1,  -- Send to bottom to allow all popups to appear on top
    winhighlight = "Normal:Normal"
  })

  -- Enable wrap for long lines
  vim.api.nvim_win_set_option(preview_win, "wrap", true)

  -- Store state
  preview_state.win = preview_win
  preview_state.buf = buf
end

-- Debounced preview update
local function debounced_update_preview(filename)
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
  if not preview_config.enabled then
    return
  end

  -- Don't show preview in visual mode
  local mode = vim.fn.mode()
  if mode:match("[vV\22]") then
    close_preview_window()
    return
  end

  -- Only work in kanban files
  local buf_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
  if not (buf_name == "todo.md" or buf_name == "doing.md" or buf_name == "done.md") then
    close_preview_window()
    return
  end

  local line = vim.api.nvim_get_current_line()
  local filename = extract_filename_from_line(line)

  if filename and filename ~= preview_state.last_file then
    preview_state.last_file = filename
    debounced_update_preview(filename)
  elseif not filename then
    close_preview_window()
    preview_state.last_file = nil
  end
end

-- Setup preview autocmds
local function setup_preview_autocmds()
  if preview_state.autocmd_group then
    return
  end

  preview_state.autocmd_group = vim.api.nvim_create_augroup("KanbanPreview", { clear = true })

  vim.api.nvim_create_autocmd("CursorMoved", {
    group = preview_state.autocmd_group,
    pattern = {"todo.md", "doing.md", "done.md"},
    callback = handle_cursor_moved
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    group = preview_state.autocmd_group,
    pattern = {"todo.md", "doing.md", "done.md"},
    callback = close_preview_window
  })
end

-- ==================== KANBAN CORE FUNCTIONS ====================

-- Open file in floating popup
local function ke_open_file()
  local filename = vim.fn.expand("<cfile>")
  if filename == "" or vim.fn.filereadable(filename) ~= 1 then
    print("No hay un archivo válido bajo el cursor.")
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
    focusable = true,  -- Allow editing in this window
    zindex = 1,  -- Send to bottom to allow completion popups (50+) to appear on top
    winhighlight = "Normal:Normal,FloatBorder:FloatBorder"
  })

  -- Enable line numbers
  vim.api.nvim_win_set_option(win, "number", true)
  vim.api.nvim_win_set_option(win, "relativenumber", false)
  

end

-- Open or create file with header
local function open_or_create_with_header(file, header)
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

-- Open Kanban board
local function kanban_open()
  -- Open in reverse order to get correct layout
  open_or_create_with_header("done.md", "DONE")
  vim.cmd("vsplit")
  open_or_create_with_header("doing.md", "DOING")
  vim.cmd("vsplit")
  open_or_create_with_header("todo.md", "TODO")

  vim.cmd("wincmd h")  -- Go to first window

  vim.cmd("wincmd =")

  if preview_config.enabled then
    setup_preview_autocmds()
  end
end

-- Rename file under cursor
local function kr_rename_file()
  local name = vim.fn.expand("<cfile>")
  if name == "" then
    print("No hay archivo válido bajo el cursor")
    return
  end

  local cwd = vim.fn.getcwd()
  local old_path = cwd .. "/" .. name

  if vim.fn.filereadable(old_path) ~= 1 then
    print("Archivo no encontrado: " .. old_path)
    return
  end

  -- Show name with spaces for better readability
  local display_name = name:gsub("_", " ")
  local new_name = vim.fn.input("Renombrar a: ", display_name)
  if new_name == "" or new_name == display_name then
    print("Renombrado cancelado")
    return
  end

  -- Convert spaces to underscores for actual filename
  local actual_new_name = new_name:gsub(" ", "_")
  local new_path = cwd .. "/" .. actual_new_name

  -- Rename file on disk
  if vim.fn.rename(old_path, new_path) ~= 0 then
    print("Error renombrando archivo")
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

  -- Update content inside file
  local file_buf = vim.fn.bufnr(new_path)
  if file_buf == -1 then
    file_buf = vim.fn.bufadd(new_path)
    vim.fn.bufload(file_buf)
  end

  -- Replace first occurrence inside file
  local lines = vim.api.nvim_buf_get_lines(file_buf, 0, -1, false)
  local replaced = false
  for i, l in ipairs(lines) do
    if not replaced and l:find(name, 1, true) then
      lines[i] = l:gsub(name, actual_new_name, 1)
      replaced = true
    end
  end
  vim.api.nvim_buf_set_lines(file_buf, 0, -1, false, lines)

  vim.api.nvim_buf_call(file_buf, function()
    vim.cmd("write!")
  end)

  print("Archivo renombrado: " .. name .. " → " .. actual_new_name)
end

-- Create new file from selection or input
local function create_new_file()
  local mode = vim.fn.mode()
  local filename = nil
  local original_text = nil
  local start_line = nil
  local end_line = nil
  local start_col = nil
  local end_col = nil

  -- Check if we're in visual mode
  if mode:match("[vV\22]") then
    -- Get visual selection boundaries
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")

    start_line = start_pos[2]
    end_line = end_pos[2]
    start_col = start_pos[3]
    end_col = end_pos[3]

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
      print("Error: Solo se permite seleccionar texto de una sola línea")
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
    print("Error: el archivo ya existe.")
    return
  end

  -- Create directories if needed
  local dir = vim.fn.fnamemodify(filename, ":h")
  if dir ~= "" and vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end

  -- Create empty file
  vim.fn.writefile({}, filename)

  print("Creado: " .. filename)

  -- Update selected text in visual mode to show the new filename
  if mode:match("[vV\22]") and original_text and start_line then
    -- Replace the selected text using API
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local start_line = start_pos[2] - 1  -- 0-indexed for API
    local start_col = start_pos[3] - 1  -- 0-indexed for API
    local end_col = end_pos[3]          -- end_pos is already inclusive

    local lines = vim.api.nvim_buf_get_lines(0, start_line, start_line + 1, false)
    if lines and lines[1] then
      local line = lines[1]
      local new_line = line:sub(1, start_col) .. filename .. line:sub(end_col + 1)
      vim.api.nvim_buf_set_lines(0, start_line, start_line + 1, false, {new_line})
    end
  else
    -- Normal mode - insert in current file (the column)
    local row = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(0, row, row, false, { filename })
  end
end

-- Delete file under cursor with confirmation
local function delete_file_under_cursor()
  local filename = vim.fn.expand("<cfile>")
  if filename == "" then
    print("No hay archivo válido bajo el cursor")
    return
  end

  local cwd = vim.fn.getcwd()
  local file_path = cwd .. "/" .. filename

  if vim.fn.filereadable(file_path) ~= 1 then
    print("Archivo no encontrado: " .. filename)
    return
  end

  -- Ask for confirmation
  local choice = vim.fn.confirm("¿Estás seguro de eliminar '" .. filename .. "'?", "&Sí\n&No", 2)
  if choice ~= 1 then
    print("Eliminación cancelada")
    return
  end

  -- Close buffer if open
  local buf = vim.fn.bufnr(file_path, false)
  if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end

  -- Delete file from disk
  if vim.fn.delete(file_path) ~= 0 then
    print("Error eliminando archivo: " .. filename)
    return
  end

  -- Remove from Kanban line
  local line = vim.api.nvim_get_current_line()
  local new_line = line:gsub(vim.pesc(filename), "", 1)
  new_line = new_line:gsub("%s+$", "")
  vim.api.nvim_set_current_line(new_line)

  print("Archivo eliminado: " .. filename)
end

-- Close Kanban splits
local function close_kanban_splits()
  local kanban_files = { "todo.md", "doing.md", "done.md" }

  -- Close preview window first
  close_preview_window()

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

-- ==================== PREVIEW MANAGEMENT ====================

-- Enable preview
local function enable_preview()
  preview_config.enabled = true
  setup_preview_autocmds()
  vim.notify("Kanban preview enabled")
end

-- Disable preview
local function disable_preview()
  preview_config.enabled = false
  close_preview_window()
  if preview_state.autocmd_group then
    vim.api.nvim_clear_autocmds({ group = preview_state.autocmd_group })
    preview_state.autocmd_group = nil
  end
  vim.notify("Kanban preview disabled")
end

-- Toggle preview
local function toggle_preview()
  if preview_config.enabled then
    disable_preview()
  else
    enable_preview()
  end
end

-- ==================== KEYMAPS ====================

-- File operations
vim.keymap.set("n", "<leader>ke", ke_open_file, {
  silent = true,
  desc = " Abrir archivo bajo el cursor en popup guardable"
})

vim.keymap.set("n", "<leader>ko", kanban_open, {
  silent = true,
  desc = " Abrir tablero Kanban en 3 splits verticales"
})

vim.keymap.set("n", "<leader>kr", kr_rename_file, {
  silent = true,
  desc = " Renombrar archivo bajo el cursor"
})

vim.keymap.set("n", "<leader>kn", create_new_file, {
  silent = true,
  desc = "Crear archivo nuevo y añadirlo a la columna"
})

vim.keymap.set("v", "<leader>kn", create_new_file, {
  silent = true,
  desc = "Crear archivo desde selección y añadirlo a la columna"
})



vim.keymap.set("n", "<leader>kd", delete_file_under_cursor, {
  silent = true,
  desc = " Eliminar archivo bajo el cursor con confirmación"
})

vim.keymap.set("n", "<leader>kc", close_kanban_splits, {
  silent = true,
  desc = " Cerrar splits del Kanban y sus buffers"
})

-- Preview controls
vim.keymap.set("n", "<leader>kp", toggle_preview, {
  silent = true,
  desc = " Toggle Kanban preview"
})

vim.keymap.set("n", "<leader>kt", toggle_preview, {
  silent = true,
  desc = " Toggle Kanban preview"
})

-- ==================== USER COMMANDS ====================

vim.api.nvim_create_user_command('KanbanPreviewToggle', toggle_preview, {})
vim.api.nvim_create_user_command('KanbanPreviewLines', function(opts)
  local lines = tonumber(opts.args) or 5
  preview_config.preview_lines = lines
  vim.notify('Preview lines set to ' .. lines)
end, { nargs = '?' })

-- ==================== INITIALIZATION ====================

-- Initialize preview on startup
if preview_config.enabled then
  setup_preview_autocmds()
end

return M
