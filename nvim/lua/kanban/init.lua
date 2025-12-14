-- Kanban plugin for Neovim
-- Provides a simple Kanban board with file management and preview functionality

local M = {}

-- Import modules
local config = require("kanban.config")
local file_ops = require("kanban.file_ops")
local ui = require("kanban.ui")
local preview = require("kanban.preview")

-- Setup function to configure plugin
function M.setup(opts)
  config.setup(opts)
  
  -- Always initialize preview autocmds (they check if enabled internally)
  preview.setup_preview_autocmds()
end

-- ==================== KEYMAPS ====================

-- File operations
vim.keymap.set("n", "<leader>ke", ui.open_file, {
  silent = true,
  desc = " Abrir archivo bajo el cursor en popup guardable"
})

vim.keymap.set("n", "<leader>ko", ui.kanban_open, {
  silent = true,
  desc = " Abrir tablero Kanban en 3 splits verticales"
})

vim.keymap.set("n", "<leader>kr", file_ops.rename_file_under_cursor, {
  silent = true,
  desc = " Renombrar archivo bajo el cursor"
})

vim.keymap.set("n", "<leader>kn", file_ops.create_new_file, {
  silent = true,
  desc = "Crear archivo nuevo y añadirlo a la columna"
})

vim.keymap.set("v", "<leader>kn", file_ops.create_new_file, {
  silent = true,
  desc = "Crear archivo desde selección y añadirlo a la columna"
})

vim.keymap.set("n", "<leader>kd", file_ops.delete_file_under_cursor, {
  silent = true,
  desc = " Eliminar archivo bajo el cursor con confirmación"
})

vim.keymap.set("n", "<leader>kc", ui.close_kanban_splits, {
  silent = true,
  desc = " Cerrar splits del Kanban y sus buffers"
})

-- Preview controls
vim.keymap.set("n", "<leader>kp", preview.toggle_preview, {
  silent = true,
  desc = " Toggle Kanban preview"
})

vim.keymap.set("n", "<leader>kt", preview.toggle_preview, {
  silent = true,
  desc = " Toggle Kanban preview"
})

-- ==================== USER COMMANDS ====================

vim.api.nvim_create_user_command('KanbanPreviewToggle', preview.toggle_preview, {})
vim.api.nvim_create_user_command('KanbanPreviewLines', function(opts)
  local lines = tonumber(opts.args) or 5
  local preview_config = config.get_section("preview")
  preview_config.preview_lines = lines
  vim.notify('Preview lines set to ' .. lines, vim.log.levels.INFO)
end, { nargs = '?' })

-- ==================== EXPORTS ====================

-- Export main functions for external use
M.open_file = ui.open_file
M.kanban_open = ui.kanban_open
M.create_new_file = file_ops.create_new_file
M.rename_file = file_ops.rename_file_under_cursor
M.delete_file = file_ops.delete_file_under_cursor
M.close_kanban = ui.close_kanban_splits
M.toggle_preview = preview.toggle_preview
M.enable_preview = preview.enable_preview
M.disable_preview = preview.disable_preview

-- Auto-initialize when plugin is loaded
M.setup()

return M