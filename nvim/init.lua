-- Neovim init.lua that simply sources your existing ~/.vimrc
-- This allows you to keep using your Vim configuration in Neovim.

-- 1) Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git', '--branch=stable', lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
vim.opt.termguicolors = true

-- Lua para init.lua
--local function generate_getters_setters()
  --local lines = vim.fn.getline("'<", "'>")
  --local result = {}
  --for _, line in ipairs(lines) do
    --local name = line:match("%s*[%w_]+%s+([%w_]+)")
    --if name then
      --table.insert(result, "function get" .. name:sub(1,1):upper()..name:sub(2) .. "() return self." .. name .. " end")
      --table.insert(result, "function set" .. name:sub(1,1):upper()..name:sub(2) .. "(val) self." .. name .. " = val end")
    --end
  --end
  --vim.fn.setline("'>", result)
--end

--vim.api.nvim_create_user_command('GenGettersSetters', generate_getters_setters, {range=true})


-- 2) Load plugins (spec at nvim/lua/plugins.lua)
pcall(function()
  require('lazy').setup(require('plugins'))
end)

-- 3) Load Lua options
pcall(function()
  require('options')
end)

-- 4) Load Lua globals (migration of Vimscript `let`)
pcall(function()
  require('globals')
end)


-- 5) Load UI (colorscheme and highlights)
pcall(function()
  require('ui')
end)

-- 6) Load plugin configs
pcall(function()
  require('plugin.ibl')
  require('plugin.noice')
  require('plugin.treesitter')
  require('plugin.ufo')
end)

-- Load keymaps
pcall(function()
  require('maps')
end)

-- 7) Load autocmds
pcall(function()
  require('autocmds')
end)

require("gen_cpp_actions")
require("kanban")
