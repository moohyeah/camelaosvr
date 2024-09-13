if not ao then ao = require('ao') end
if not bint then bint = require('.bint')(256) end
if not Random then Random = require('.chance') end

local json = require('json')
local pretty = require(".pretty")

Name = "Watermelon game test logic"
Desc = "The Watermelon test game logic"
TokenId = TokenId or "2RLwmjFijKkoRko-9Mr6aJBQFRaV1OB3Q8IeOFNuqRI"

ACHIEVEMENT_TARGET ='t5n70p0zPQsro-NZxIuGX4izLJF5-lixZvRs04eLZoY'

EnergyRecoverTime = EnergyRecoverTime or 1 * 60 * 1000 -- 1 hour
LastUpdateTime = LastUpdateTime or nil
Now = Now or os.time()

---@class game logic
game = game or {}

---@table  coroutines pool
game.co_pool = game.co_pool or {}

---@class Player
Player = {}

TaskCfg = {
    [1] = {taskRewardNum = 1, isDaily = false},
    [2] = {taskRewardNum = 1, isDaily = false},
    -- [3] = {taskRewardNum = 1, isDaily = false},
    -- [4] = {taskRewardNum = 1, isDaily = false},
    [5] = {taskRewardNum = 1, isDaily = true},
    [6] = {taskRewardNum = 1, isDaily = true},
    [7] = {taskRewardNum = 1, isDaily = true},
    -- [8] = {taskRewardNum = 1, isDaily = true},
    [9] = {taskRewardNum = 1, isDaily = true},
    [10] = {taskRewardNum = 3, isDaily = false},
    [101] = {taskRewardNum = 10, isDaily = false},
    [102] = {taskRewardNum = 3, isDaily = true},
}

function Player:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    o.level = 0
    o.energy = 10
    o.score = 0
    o.timeline = {} -- Record player operation sequence
    o.randoms = {} -- random list {}
    o.state = "idle" -- idle or playing
    self:ResetTask()
    return o
end

function Player:AddEnergy(num)
    self.energy = self.energy + num
    if self.energy > 10 then
        self.energy = 10
    end
end

function Player:ResetTask()
    local isNew = false
    if not self.tasks then
        self.tasks = {}
        isNew = true
    end
    for k, v in pairs(TaskCfg) do
        if v.isDaily or isNew then
            self.tasks[k] = {recieved = false}
        end
    end
end

---@map players
Players = Players or {}

--[[
     gen a random list for 10 numbers, per number is between 1 and 10
]]--
local _getRandomList = function()
    Random.seed(Now)
    local random_list = {}
    for i = 1, 100, 1 do
        random_list[i] = Random.integer(1, 10)
    end
    return random_list
end

-- function list
--[[
    Play a game, need 1 Engry pre.

    - From: string , player address
]]--
game.Play = function(msg)
    if not Players[msg.From] then
        Players[msg.From] = Player:new(nil)
    end
    local player = Players[msg.From]

    player.state = "playing"
    -- clear timeline
    player.timeline = {}
    -- clear randoms
    player.randoms = {}
    -- gen 100 random numbers
    local rondom100 = _getRandomList()
    player.randoms[#player.randoms+1] = rondom100

    ao.send({
        Target = msg.From,
        Data = "success",
        Randoms = json.encode(rondom100)
    })
end

--[[
    Get player's Energy

    - From: string , player address
]]--
game.Energy = function(msg)
    if not Players[msg.From] then
        Players[msg.From] = Player:new(nil)
    end

    ao.send({
        Target = msg.From,
        Data = tostring(Players[msg.From].energy)
    })
end

--[[
    Exit game and get score

    - From: string, player address
    - score: string, score of this game
]]--
local _exit = function(msg)
    assert(type(msg.Tags.Score) == 'string', 'Score is required!')
    assert(bint(0) <= bint(msg.Tags.Score), 'Score must be greater than 0')
    if not Players[msg.From] then
        Players[msg.From] = Player:new(nil)
    end

    local player = Players[msg.From]
    if player.state ~= "playing" then
        ao.send({
            Target = msg.From,
            Action = 'Verify-Error',
            Data = "Failed",
            Error = "Player is not playing the game"
        })
        return
    end

    player.state = "idle"

    local valid = game.Verify(msg.From, tonumber(msg.Tags.Score), tonumber(msg.Tags.CheckSum))
    if valid then
        local tokens = game.CalculateToken(bint(msg.Tags.Score))
        -- mint token for player
        game.Mint(msg.From, tokens)
        -- wait for minting tokens
        --coroutine.yield()
        -- ao.send({ Target = TokenId, Action = "Transfer", Recipient = msg.From, Quantity = tostring(tokens)})
        
        -- send msg to player
        ao.send({
            Target = msg.From,
            Tokens = tostring(tokens),
            Data = "success",
        })

        if tonumber(msg.Tags.Score) == 100 then
            ao.send({
                Target = ACHIEVEMENT_TARGET,
                Tags = {
                    Action ='AppendAchievement',
                },
                Data = json.encode({
                    title ='yalla jamel：The King of Kings ',
                    description='I defeat 99.99% person. What about you?',
                    proven = "",
                    address = msg.From
                })
            })
        end    
    else
        ao.send({
            Target = msg.From,
            Action = 'Verify-Error',
            Data = "Failed",
            Error = "Verify failed"
        })
    end
end

game.Exit = function(msg)
    --[[ use coroutine
    game.co_pool[msg.From] = coroutine.create(_exit)
    -- call and await
    coroutine.resume(game.co_pool[msg.From], msg) 
    ]]--

    _exit(msg)
end

--[[
     verify 

     -- player_addr: string
     -- score: int 
     -- return: bool
]]--
game.Verify = function(player_addr, score, check_sum)
    local player = Players[player_addr]
    local randVal = player.randoms[#player.randoms][score]
    -- print(player_addr .. "," .. check_sum .. "," .. score .. "," .. randVal)
    return randVal == check_sum
end

--[[
    Get player's Energy

    - From: string , player address
]]--
game.Energy = function(msg)
    if not Players[msg.From] then
        Players[msg.From] = Player:new(nil)
    end

    ao.send({
        Target = msg.From,
        Data = tostring(Players[msg.From].energy)
    })
end

--[[
    finish game task
    - From: string, player address
    - score: string, score of this game
]]--
game.FinishTask = function(msg)
    assert(type(msg.Tags.TaskId) == 'string', 'TaskId is required!')
    assert(bint(0) <= bint(msg.Tags.TaskId), 'TaskId must be greater than 0')
    
    if not Players[msg.From] then
        Players[msg.From] = Player:new(nil)
    end

    local player = Players[msg.From]
    if not player.tasks then
        Player.ResetTask(player)
    end

    local taskCfg = TaskCfg[tonumber(msg.Tags.TaskId)]
    assert(taskCfg, 'Task not Exist!')

    if not player.tasks[tonumber(msg.Tags.TaskId)].recieved then
        local tokens = taskCfg.taskRewardNum
        -- mint token for player
        game.Mint(msg.From, tokens)
        -- wait for minting tokens
        --coroutine.yield()
        -- ao.send({ Target = TokenId, Action = "Transfer", Recipient = msg.From, Quantity = tostring(tokens)})
        
        -- send msg to player
        ao.send({
            Target = msg.From,
            Tokens = tostring(tokens),
            Data = "success",
        })
    else
        ao.send({
            Target = msg.From,
            Action = 'Finsh-Error',
            Data = "Failed",
            Error = "Finsh failed"
        })
    end
end

--[[
     Calculate how many tokens can get based on the score

     -- score: int
     -- return: int, number of the tokens
]]--
game.CalculateToken = function (score)
    if score >= 80 then
        return 2
    elseif score >= 60 then
        return 1
    end
    return 0
    -- return 10
end

--[[
     Mint tokens to the player

     -- score: int
     -- return: int, number of the tokens
]]--
game.Mint = function (player_addr, tokens)
    print("===Mint:" .. player_addr .. "," .. tokens)
    local msg = ao.send({
        Target = TokenId,
        Action = "Mint",
        Quantity = tostring(tokens),
        To = player_addr
    })
    -- local msg = {
    --     From = ao.id,
    --     Quantity = tostring(tokens),
    --     Tags = {
    --         To = player_addr,
    --     }
    -- }
    -- for _, hanlder in pairs(Handlers.list) do
    --     if "mint" == hanlder.name then
    --         hanlder.handle(msg, ao.env)
    --     end
    -- end
    -- print(pretty.tprint(msg))
end

--[[
     Mint success message from TokenId process
     Used to release the coroutine
]]--
game.MintResponse = function(msg)
    coroutine.resume(game.co_pool[msg.MintTo])

    -- release coroutine
    game.co_pool[msg.MintTo] = nil
end


--[[
     Game tick
]]--
game.CronTick = function(msg)
    Now = msg.Timestamp
    if not LastUpdateTime then
        LastUpdateTime = Now
    end

    --[[
     Reset Game Task Daily
    ]]--
    if os.date("*t", LastUpdateTime).day ~= os.date("*t", LastUpdateTime).Now  then
        for _, player in pairs(Players) do
            player:ResetTask()
        end
        LastUpdateTime = Now
    end

    -- recover player's energy
    -- if Now - LastUpdateTime > EnergyRecoverTime then
    --     for _, player in pairs(Players) do
    --         player:AddEnergy(1)
    --     end
    --     LastUpdateTime = Now

    --     ao.send({
    --         Target = ao.id,
    --         Data = "add energy for all players",
    --     })
    -- end
    
end

--[[
     GetRandom
]]--
game.GetRandom = function(msg)
    if not Players[msg.From] then
        Players[msg.From] = Player:new(nil)
    end

    local player = Players[msg.From]
    if player.state ~= "playing" then
        ao.send({
            Target = msg.From,
            Data = "Failed",
            Error = "Player is not playing the game"
        })
        return
    end

    local rondom10 = _getRandomList()

    ao.send({
        Target = msg.From,
        Data = "success",
        Randoms = json.encode(rondom10)
    })

    -- save random list    
    player.randoms[#player.randoms+1] = rondom10
end


-- registry handlers
Handlers.add('play', Handlers.utils.hasMatchingTag('Action', 'Play'), game.Play)
Handlers.add('finishTask', Handlers.utils.hasMatchingTag('Action', 'FinishTask'), game.FinishTask)
Handlers.add('energy', Handlers.utils.hasMatchingTag('Action', 'Energy'), game.Energy)
Handlers.add('exit', Handlers.utils.hasMatchingTag('Action', 'Exit'), game.Exit)
-- Handlers.add('mint-success', Handlers.utils.hasMatchingTag('Action', 'Mint-Success'), game.MintResponse)
Handlers.add("CronTick", Handlers.utils.hasMatchingTag("Action", "Cron"), game.CronTick)
Handlers.add("random", Handlers.utils.hasMatchingTag("Action", "Random"), game.GetRandom)

return game