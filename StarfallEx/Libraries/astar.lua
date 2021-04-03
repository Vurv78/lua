--@name AStar
--@author lattejed on github
--@shared

-- Original Source https://github.com/lattejed/a-star-lua.
-- Modified to work with glua vectors if I can recall correctly.

local module = {}

local INF = 1/0
local cachedPaths = nil

----------------------------------------------------------------
-- local functions
----------------------------------------------------------------

local function dist_between(nodeA,nodeB)
    return nodeA:getDistance(nodeB)
end

local function is_valid_node ( node, neighbor )
    return true
end

local function lowest_f_score ( set, f_score )
    local lowest, bestNode = INF, nil
    for _, node in ipairs ( set ) do
        local score = f_score [ node ]
        if score < lowest then
            lowest, bestNode = score, node
        end
    end
    return bestNode
end

local function neighbor_nodes(theNode,nodes)
    local neighbors = {}
    for _, node in ipairs ( nodes ) do
        if theNode ~= node and is_valid_node ( theNode, node ) then
            table.insert ( neighbors, node )
        end
    end
    return neighbors
end

local function not_in ( set, theNode )
    for _, node in ipairs ( set ) do
        if node == theNode then return false end
    end
    return true
end

local function remove_node ( set, theNode )
    for i, node in ipairs ( set ) do
        if node == theNode then 
            set [ i ] = set [ #set ]
            set [ #set ] = nil
            break
        end
    end
end

local function unwind_path ( flat_path, map, current_node )
    if map [ current_node ] then
        table.insert ( flat_path, 1, map [ current_node ] ) 
        return unwind_path ( flat_path, map, map [ current_node ] )
    else
        return flat_path
    end
end

----------------------------------------------------------------
-- pathfinding functions
----------------------------------------------------------------

local function a_star ( start, goal, nodes, valid_node_func , canRun)
    local closedset = {}
    local openset = { start }
    local came_from = {}

    if valid_node_func then is_valid_node = valid_node_func end

    local g_score, f_score = {}, {}
    g_score [ start ] = 0
    f_score [ start ] = g_score [ start ] + dist_between ( start, goal )
    while #openset > 0 do
        if canRun and not canRun() then coroutine.yield() end
        local current = lowest_f_score ( openset, f_score )
        if current == goal then
            local path = unwind_path ( {}, came_from, goal )
            table.insert ( path, goal )
            return path
        end
        remove_node ( openset, current )
        table.insert ( closedset, current )
        local neighbors = neighbor_nodes ( current, nodes )
        for _, neighbor in ipairs ( neighbors ) do
            if not_in ( closedset, neighbor ) then
                local tentative_g_score = g_score [ current ] + dist_between ( current, neighbor )
                if not_in ( openset, neighbor ) or tentative_g_score < g_score [ neighbor ] then 
                    came_from     [ neighbor ] = current
                    g_score     [ neighbor ] = tentative_g_score
                    f_score     [ neighbor ] = g_score [ neighbor ] + dist_between ( neighbor, goal )
                    if not_in ( openset, neighbor ) then
                        table.insert ( openset, neighbor )
                    end
                end
            end
        end
    end
    return nil -- no valid path
end

----------------------------------------------------------------
-- exposed functions
----------------------------------------------------------------

local function clear_cached_paths ()
    cachedPaths = nil
end

local function path( start, goal, nodes, ignore_cache, valid_node_func,canRun)
    if not cachedPaths then cachedPaths = {} end
    if not cachedPaths [ start ] then
        cachedPaths [ start ] = {}
    elseif cachedPaths [ start ] [ goal ] and not ignore_cache then
        return cachedPaths [ start ] [ goal ]
    end

    local resPath = a_star ( start, goal, nodes, valid_node_func,canRun)
    if not cachedPaths [ start ] [ goal ] and not ignore_cache then
        cachedPaths [ start ] [ goal ] = resPath
    end
    return resPath
end

module.clear_cached_paths = clear_cached_paths
module.path = path

return module