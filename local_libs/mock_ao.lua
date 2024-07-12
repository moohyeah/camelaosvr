local pretty = require('./local_libs/pretty')

local ao = {}
ao.send = function (msg)
    local l = pretty.tprint(msg, 2)
    print(l)
end

return ao