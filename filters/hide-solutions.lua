-- Remove solution blocks unless the document sets `show-solutions: true` in YAML

local showSolutions = false

local function toBoolean(value)
  if type(value) == 'boolean' then
    return value
  end
  local s = pandoc.utils.stringify(value or ''):lower()
  return (s == 'true' or s == 'yes' or s == '1' or s == 'on')
end

local function MetaPass(meta)
  if meta["show-solutions"] ~= nil then
    showSolutions = toBoolean(meta["show-solutions"])
  else
    showSolutions = false
  end
  return meta
end

local function hasClass(el, klass)
  for _, cls in ipairs(el.classes) do
    if cls == klass then return true end
  end
  return false
end

local function DivPass(el)
  if not showSolutions and hasClass(el, 'solution') then
    return pandoc.Null()
  end
  return el
end

return {
  { Meta = MetaPass },
  { Div = DivPass },
}
