-- gen_cpp_getters.lua
-- Generador de getters/setters C++ usando Tree-sitter y plantillas multilínea

local ts = vim.treesitter
local ts_utils = require("nvim-treesitter.ts_utils")

-- 📦 Carga plantillas multilínea separadas por "KEY:" en el archivo .tpl
local function load_templates(file)
  local templates = {}
  local current_key = nil
  local current_lines = {}

  local f = io.open(file, "r")
  if not f then
    vim.notify("No se pudo abrir el archivo de plantilla: " .. file, vim.log.levels.ERROR)
    return templates
  end

  for line in f:lines() do
    local key = line:match("^(%w+):%s*$")
    if key then
      if current_key then
        templates[current_key] = table.concat(current_lines, "\n")
      end
      current_key = key
      current_lines = {}
    elseif current_key then
      table.insert(current_lines, line)
    end
  end
  f:close()

  if current_key then
    templates[current_key] = table.concat(current_lines, "\n")
  end

  if not templates.GETTER or not templates.SETTER then
    vim.notify("Advertencia: faltan GETTER o SETTER en la plantilla", vim.log.levels.WARN)
  end

  return templates
end


-- 🪄 Convierte m_snake_case → CamelCase
local function to_camel_case(name)
  name = name:gsub("^m_", "") -- quitar prefijo m_
  return name:gsub("_(%l)", function(c) return c:upper() end)
             :gsub("^%l", string.upper)
end

-- 📄 Renderiza plantillas (simple, sin dependencias externas)
local function render_template(template, vars)
  return (template:gsub("{{(%w+)}}", function(key)
    return vars[key] or ""
  end))
end

-- ⚙️ Genera getters/setters y los inserta en la sección public:
local function generate_getters_setters()
  local lang = vim.bo.filetype
  local parser = ts.get_parser(0, lang)
  local tree = parser:parse()[1]
  local root = tree:root()

  local start_row = vim.fn.getpos("'<")[2] - 1
  local end_row = vim.fn.getpos("'>")[2]

  -- Query Tree-sitter para variables miembro
  local query = ts.query.parse("cpp", [[
    (field_declaration
      type: (_) @type
      declarator: (field_identifier) @name)
  ]])

  local variables = {}
  for id, node in query:iter_captures(root, 0, start_row, end_row) do
    local capname = query.captures[id]
    local text = vim.treesitter.get_node_text(node, 0)
    if capname == "type" then
      table.insert(variables, { type = text })
    elseif capname == "name" then
      if #variables > 0 then
        variables[#variables].name = text
      end
    end
  end

  if #variables == 0 then
    vim.notify("No se detectaron variables en la selección", vim.log.levels.WARN)
    return
  end

  -- 🧩 Cargar plantillas
  local templates = load_templates("/home/dai/.config/nvim/lua/cpp_getset.tpl")

  -- 📚 Generar líneas de código con indentación real (1 tab)
  local generated = {}
  for _, v in ipairs(variables) do
    local vars = {
      type = v.type,
      name = v.name,
      CapName = to_camel_case(v.name),
    }

    local getter = render_template(templates.GETTER, vars)
    local setter = render_template(templates.SETTER, vars)

    -- dividir en líneas y agregar tabs
    for subline in getter:gmatch("[^\r\n]+") do
      table.insert(generated, "\t" .. subline)
    end
    for subline in setter:gmatch("[^\r\n]+") do
      table.insert(generated, "\t" .. subline)
    end
    table.insert(generated, "") -- línea en blanco entre bloques
  end

  -- 🔍 Buscar sección "public:" para insertar allí
  local buf_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local insert_line = nil
  for i, l in ipairs(buf_lines) do
    if l:match("^%s*public:") then
      insert_line = i
      break
    end
  end

  -- 🧩 Insertar donde corresponda
  if insert_line then
    vim.api.nvim_buf_set_lines(0, insert_line, insert_line, false, generated)
    vim.notify("Getters y setters insertados en sección 'public:'", vim.log.levels.INFO)
  else
    vim.api.nvim_buf_set_lines(0, end_row, end_row, false, generated)
    vim.notify("Getters y setters insertados tras la selección", vim.log.levels.INFO)
  end
end

vim.api.nvim_create_user_command("GenGettersSetters", generate_getters_setters, { range = true })
