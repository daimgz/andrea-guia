-- lua/gen_cpp_actions.lua
require("gen_cpp_getters_improved")
local M = {}

local function gen_getters_setters()
  require("gen_cpp_getters").generate_getters_setters()
end

local function gen_constructor()
  print("Constructor generation not implemented yet 😄")
end

local function gen_tostring()
  print("toString() generation not implemented yet 😄")
end

M.actions = {
  { name = "Generate Getters/Setters", func = gen_getters_setters },
  { name = "Generate Constructor", func = gen_constructor },
  { name = "Generate toString()", func = gen_tostring },
}

function M.show_menu()
  local items = {}
  for _, a in ipairs(M.actions) do
    table.insert(items, a.name)
  end

  vim.ui.select(items, { prompt = "C++ Actions:" }, function(choice)
    if not choice then return end
    for _, a in ipairs(M.actions) do
      if a.name == choice then
        a.func()
        return
      end
    end
  end)
end

vim.api.nvim_create_user_command("CppActions", M.show_menu, {})
return M
