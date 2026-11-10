-- Formats the ISO date from post.json (e.g. "2026-11-02") as "2 November 2026",
-- matching the Elm format "d MMMM y". The result is exposed as `date-display`.

local months = {
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
}

function Meta(meta)
  if meta.date then
    local iso = pandoc.utils.stringify(meta.date)
    local y, m, d = iso:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
    if y then
      meta["date-display"] = string.format("%d %s %s", tonumber(d), months[tonumber(m)], y)
    else
      meta["date-display"] = iso
    end
  end
  return meta
end
