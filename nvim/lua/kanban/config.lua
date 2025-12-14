-- Configuration management for Kanban plugin

local M = {}

-- Default configuration
local default_config = {
  preview = {
    enabled = true,
    preview_lines = 3,
    debounce_time = 200,
    max_file_size = 50 * 1024,  -- 50KB
    text_extensions = {".md", ".txt", ".lua", ".py", ".js", ".ts", ".json", ".yaml", ".yml", ".toml", ".sh", ".zsh"}
  }
}

-- Current configuration (starts with defaults)
local config = vim.tbl_deep_extend("force", {}, default_config)

-- Setup function to configure the plugin
function M.setup(opts)
  if opts then
    config = vim.tbl_deep_extend("force", config, opts)
  end
  return config
end

-- Get current configuration
function M.get()
  return config
end

-- Get specific configuration section
function M.get_section(section)
  return config[section] or {}
end

-- Reset to defaults
function M.reset()
  config = vim.tbl_deep_extend("force", {}, default_config)
  return config
end

return M