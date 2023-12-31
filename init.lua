chatgames = {}

chatgames.games = {}
chatgames.active_game = nil

function string_to_bool(str)
    if str == nil then return nil end
    if type(str) ~= 'string' then
        return nil
    end

    str = string.lower(str) -- Convert the string to lowercase

    if str == "true" or str == "yes" or str == "1" then
        return true
    elseif str == "false" or str == "no" or str == "0" then
        return false
    else
        return nil
    end
end

function bool_to_string(b)
    if b then
        return "true"
    else
        return "false"
    end
end


-- Function to register a game
function chatgames.register_game(game_name, answer_func)
    if not chatgames.games[game_name] then
        chatgames.games[game_name] = {
            answer_func = answer_func,
            questions = {}
        }
    else
        minetest.log("error", "[chatgames] Game " .. game_name .. " already exists!")
    end
end

-- Function to register a question for a game
function chatgames.register_question(game_name, question, answer, is_case_sensitive)
    if chatgames.games[game_name] then
        table.insert(chatgames.games[game_name].questions, {
            question = question,
            answer = is_case_sensitive and answer or string.lower(answer),
            is_case_sensitive = is_case_sensitive
        })
    else
        minetest.log("error", "[chatgames] Game " .. game_name .. " does not exist!")
    end
end

-- Function to start a game
function chatgames.start_game(game_name)
    if chatgames.games[game_name] and #chatgames.games[game_name].questions > 0 then
        local question_id = math.random(#chatgames.games[game_name].questions)
        local question_data = chatgames.games[game_name].questions[question_id]

        chatgames.active_game = {
            game_name = game_name,
            question_id = question_id,
            start_time = os.time(),
            time_to_complete = tonumber(minetest.settings:get("chatgames.time_to_complete")) or 25
        }

        -- Send the message to all players with chatgames visibility enabled
        for _, player in ipairs(minetest.get_connected_players()) do
            local player_name = player:get_player_name()
            local meta = player:get_meta()

            if string_to_bool(meta:get_string("chatgames_enabled")) ~= false then
                minetest.chat_send_player(player_name, "[CHATGAMES] You have " .. chatgames.active_game.time_to_complete .. " seconds to answer the question '" .. question_data.question .. "'")
            end
        end

        -- Setting up the timer to end the game after the time limit
        minetest.after(chatgames.active_game.time_to_complete, function()
            if chatgames.active_game and chatgames.active_game.game_name == game_name then
                local question_data = chatgames.games[game_name].questions[chatgames.active_game.question_id]

                for _, player in ipairs(minetest.get_connected_players()) do
                    local player_name = player:get_player_name()
                    local meta = player:get_meta()

                    if string_to_bool(meta:get_string("chatgames_enabled")) ~= false then
                        minetest.chat_send_player(player_name, "[CHATGAMES] Nobody got it in time, the answer was '" .. question_data.answer .. "'")
                    end
                end

                chatgames.end_game()
            end
        end)
    else
        minetest.log("error", "[chatgames] Game " .. game_name .. " does not exist or has no questions!")
    end
end


-- Function to end a game
function chatgames.end_game(has_winners)
    chatgames.active_game = nil
end

-- Chat listener to handle game responses
minetest.register_on_chat_message(function(player_name, message)
    if chatgames.active_game then
        local game = chatgames.games[chatgames.active_game.game_name]
        local question_data = game.questions[chatgames.active_game.question_id]

        local player_response = question_data.is_case_sensitive and message or string.lower(message)
        local correct_answer = question_data.answer

        if game.answer_func(chatgames.active_game.game_name, player_name, player_response, chatgames.active_game.time_to_complete, os.time() - chatgames.active_game.start_time, chatgames.active_game.question_id) then
            -- Check if the player has chatgames enabled
            local player = minetest.get_player_by_name(player_name)
            local meta = player:get_meta()
            local player = minetest.get_player_by_name(player_name)
            minetest.log("action", "PLAYER META: " .. minetest.serialize(meta:to_table()))
            if player then
                local meta = player:get_meta()
                if meta and string_to_bool(meta:get("chatgames_enabled") or true) then
                    minetest.chat_send_player(player_name, "[CHATGAMES] " .. player_name .. " answered '" .. message .. "' and got rewards!")
                end
                chatgames.end_game(true)
                return true  -- message handled, so don't broadcast it
            else
                minetest.log("error", "[chatgames] Player not found: " .. player_name)
            end
        end
    end
    return false  -- not handled, broadcast message normally
end)

-- Function to start a random game
function chatgames.start_random_game()
    if not next(chatgames.games) then
        minetest.log("info", "[chatgames] No games registered.")
        return
    end

    local game_names = {}
    for game_name, _ in pairs(chatgames.games) do
        table.insert(game_names, game_name)
    end

    local random_game_name = game_names[math.random(#game_names)]
    chatgames.start_game(random_game_name)
end

-- Recurring timer to start a random game every 10 minutes
local function schedule_game()
    minetest.after(tonumber(minetest.settings:get("chatgames.new_game_interval")) or 600, function()
        chatgames.start_random_game()
        schedule_game()  -- Reschedule itself
    end)
end

-- Initialize the recurring game timer
schedule_game()

-- Inside the chat command function
minetest.register_chatcommand("chatgame", {
    description = "Control chatgames settings",
    func = function(player_name, param)
        local args = param:split(" ")  -- Split the parameter into arguments

        -- Check if the first argument is 'toggle'
        if args[1] == "toggle" then
            local player = minetest.get_player_by_name(player_name)
            if player then
                local meta = player:get_meta()

                -- Get the current setting; default to "true" if not set
                local current_setting = meta:get_string("chatgames_enabled")
                if current_setting == "" then
                    current_setting = "true"
                end

                -- Toggle the setting
                local new_setting = current_setting == "true" and "false" or "true"
                meta:set_string("chatgames_enabled", new_setting)

                -- Update the player with the new status
                local status = new_setting == "true" and "enabled" or "disabled"
                minetest.chat_send_player(player_name, "Chatgames visibility is now " .. status)
            else
                minetest.chat_send_player(player_name, "Error: Player not found.")
            end
        else
            -- If the first argument is not 'toggle', show usage information
            return false, "Usage: /chatgame toggle"
        end
    end,
})
