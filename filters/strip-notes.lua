local enabled = false

function Meta(m)
  local v = m["strip-notes"]
  enabled = (v == true) or (tostring(v) == "true")
end

function Div(el)
  if enabled and el.classes and el.classes:includes("notes") then
    return {}
  end
  return nil
end
