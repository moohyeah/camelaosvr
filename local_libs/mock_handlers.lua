local Handlers = {}

Handlers.utils = {}

Handlers.add = function (p1, pd, p3)
    print("mock Handlers: add: " .. p1)
end

Handlers.utils.hasMatchingTag = function (action, val)
    return true
end

return Handlers