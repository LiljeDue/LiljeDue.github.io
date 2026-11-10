-- Makes browser MathML spacing match TeX in two places:
--
-- 1. Operator names such as \log and \min. Pandoc's MathML marks these with an
--    invisible "function application" operator, but browsers give it zero
--    width, so `\log n` renders as "logn". TeX (and MathJax) put a thin space
--    between an operator name and an adjacent ordinary atom (a variable,
--    number, group or closing bracket), and no space next to an opening
--    bracket, a binary/relation symbol or explicit spacing. This filter
--    applies that rule by inserting `\,` into the TeX source.
--
-- 2. Binary operators that browsers space too tightly. TeX gives every binary
--    operator a medium space (4mu = 0.222em) on each side, but the MathML
--    operator dictionary gives \odot, \otimes, \star, \diamond, \circ, \cdot
--    and \times only 0.167em, while \oplus, + etc. get 0.222em. This filter
--    adds the missing 1mu (0.056em) on each side with `\mspace{1mu}`, but only
--    where TeX treats the symbol as binary (between two terms), not in e.g.
--    `(A, \cdot, e)` or a subscript `e_\cdot`.

local function set(list)
  local s = {}
  for _, v in ipairs(list) do s[v] = true end
  return s
end

-- Operator names (TeX "Op" atoms rendered as upright words).
local OPS = set {
  "log", "ln", "lg", "exp", "min", "max", "sup", "inf", "lim", "liminf",
  "limsup", "det", "gcd", "sin", "cos", "tan", "cot", "sec", "csc", "sinh",
  "cosh", "tanh", "coth", "arcsin", "arccos", "arctan", "arg", "deg", "dim",
  "hom", "ker", "Pr",
}

-- Commands that produce an ordinary atom.
local ORD = set {
  "alpha", "beta", "gamma", "delta", "epsilon", "varepsilon", "zeta", "eta",
  "theta", "vartheta", "iota", "kappa", "lambda", "mu", "nu", "xi", "pi",
  "varpi", "rho", "varrho", "sigma", "varsigma", "tau", "upsilon", "phi",
  "varphi", "chi", "psi", "omega", "Gamma", "Delta", "Theta", "Lambda", "Xi",
  "Pi", "Sigma", "Upsilon", "Phi", "Psi", "Omega", "infty", "ell", "partial",
  "nabla", "emptyset", "varnothing", "hbar", "aleph", "top", "bot",
}

-- Closing delimiters (TeX "Close" atoms): thin space before an operator.
local CLOSE = set { "rbrace", "rangle", "rfloor", "rceil", "rvert", "rVert" }

-- Commands whose result is an ordinary atom when they follow an operator.
local ORD_GROUP = set {
  "mathbb", "mathcal", "mathrm", "mathbf", "mathit", "mathsf", "mathfrak",
  "overline", "underline", "bar", "hat", "tilde", "vec", "dot", "ddot",
  "frac", "sqrt", "text", "operatorname",
}

-- Binary operators whose browser spacing (0.167em) is below TeX's 0.222em.
local TIGHT_BIN = set { "odot", "otimes", "star", "diamond", "circ", "cdot", "times" }

-- The spacing inserted around TIGHT_BIN operators.
local BIN_PAD = "\\mspace{1mu}"

-- Relations: a binary operator directly before one of these is not binary.
local REL = set {
  "le", "leq", "ge", "geq", "neq", "ne", "equiv", "approx", "sim", "simeq",
  "cong", "in", "notin", "ni", "subset", "subseteq", "supset", "supseteq",
  "to", "mapsto", "rightarrow", "leftarrow", "Rightarrow", "Leftarrow",
  "iff", "implies", "mid", "parallel", "perp", "prec", "succ", "preceq",
  "succeq", "ll", "gg", "propto",
}

-- Is a TIGHT_BIN operator binary given the TeX emitted before it? (TeX: a
-- binary operator after an opening bracket, punctuation, relation, operator
-- or at the start of a formula is treated as an ordinary symbol.)
local function binary_left(s)
  s = s:gsub("%s+$", "")
  if s == "" then
    return false
  end
  -- Something in a sub/superscript (e_+, e_\cdot, x^2) is part of an ordinary
  -- atom.
  if s:match("[_^]%s*\\%a+$") or s:match("[_^]%s*[^%s\\{}]$") then
    return true
  end
  local c = s:sub(-1)
  if c:match("%a") then
    local name = s:match("\\(%a+)$")
    if name then
      return ORD[name] or CLOSE[name] or false
    end
    return true
  end
  if c:match("%d") then
    return true
  end
  return c == ")" or c == "]" or c == "|" or c == "!" or c == "'" or c == "}"
end

-- Is a TIGHT_BIN operator binary given the TeX that follows it? (TeX: a
-- binary operator before a closing bracket, punctuation or relation is
-- treated as an ordinary symbol.)
local function binary_right(rest)
  rest = rest:gsub("^%s+", "")
  local c = rest:sub(1, 1)
  if c == "" then
    return false
  end
  if c:match("[%w({%[|+%-]") then
    return true
  end
  if c == "\\" then
    local name = rest:match("^\\(%a+)")
    if not name then
      local escaped = rest:sub(2, 2)
      return escaped == "{" or escaped == "|"
    end
    return not (REL[name] or CLOSE[name] or name == "right")
  end
  return false
end

-- Does the TeX emitted so far end with an atom that wants a thin space
-- before a following operator?
local function ord_before(s)
  s = s:gsub("%s+$", "")
  -- Right after a binary operator: TeX adds no extra space before an Op.
  if s:sub(-#BIN_PAD) == BIN_PAD then
    return false
  end
  local c = s:sub(-1)
  if c == "" then
    return false
  end
  if c:match("%a") then
    local name = s:match("\\(%a+)$")
    if name then
      return OPS[name] or ORD[name] or CLOSE[name] or false
    end
    return true
  end
  if c:match("%d") then
    return true
  end
  -- `}` closes a group or is `\}`; `,` here can only come from `\,` or
  -- punctuation, which already carry spacing.
  return c == ")" or c == "]" or c == "|" or c == "!" or c == "'" or c == "}"
end

-- Does the TeX following an operator start with an atom that wants a thin
-- space after the operator?
local function ord_after(rest)
  rest = rest:gsub("^%s+", "")
  local c = rest:sub(1, 1)
  if c == "" then
    return false
  end
  if c:match("[%w{|]") then
    return true
  end
  if c == "\\" then
    local name = rest:match("^\\(%a+)")
    if not name then
      return false -- \{  \,  \;  \!  \\  etc.
    end
    return OPS[name] or ORD[name] or ORD_GROUP[name] or false
  end
  return false
end

-- Index just past a balanced {...} group starting at i (tex:sub(i,i) == "{").
local function skip_group(tex, i)
  local depth = 0
  local n = #tex
  while i <= n do
    local c = tex:sub(i, i)
    if c == "\\" then
      i = i + 2
    else
      if c == "{" then
        depth = depth + 1
      elseif c == "}" then
        depth = depth - 1
        if depth == 0 then
          return i + 1
        end
      end
      i = i + 1
    end
  end
  return i
end

-- Index just past any \limits/\nolimits and sub/superscripts starting at i.
local function skip_scripts(tex, i)
  while true do
    local j = tex:find("%S", i) or (#tex + 1)
    local limits = tex:match("^\\no?limits", j) or tex:match("^\\limits", j)
    local c = tex:sub(j, j)
    if limits then
      i = j + #limits
    elseif c == "_" or c == "^" then
      j = tex:find("%S", j + 1) or (#tex + 1)
      local a = tex:sub(j, j)
      if a == "{" then
        i = skip_group(tex, j)
      elseif a == "\\" then
        local name = tex:match("^\\(%a+)", j)
        i = j + 1 + (name and #name or 1)
      else
        i = j + 1
      end
    else
      return i
    end
  end
end

local function space_operators(tex)
  local out = {}
  local i, n = 1, #tex
  while i <= n do
    local c = tex:sub(i, i)
    if c == "\\" then
      local name = tex:match("^%a+", i + 1)
      if name and OPS[name] then
        local j = skip_scripts(tex, i + 1 + #name)
        if ord_before(table.concat(out)) then
          out[#out + 1] = "\\,"
        end
        out[#out + 1] = tex:sub(i, j - 1)
        if ord_after(tex:sub(j)) then
          out[#out + 1] = "\\,"
        end
        i = j
      elseif name and TIGHT_BIN[name] then
        local j = i + 1 + #name
        if binary_left(table.concat(out)) and binary_right(tex:sub(j)) then
          out[#out + 1] = BIN_PAD .. "\\" .. name .. BIN_PAD
        else
          out[#out + 1] = "\\" .. name
        end
        i = j
      elseif name then
        out[#out + 1] = "\\" .. name
        i = i + 1 + #name
      else
        out[#out + 1] = tex:sub(i, i + 1) -- escaped char: \\ \{ \, ...
        i = i + 2
      end
    else
      out[#out + 1] = c
      i = i + 1
    end
  end
  return table.concat(out)
end

function Math(el)
  el.text = space_operators(el.text)
  return el
end
