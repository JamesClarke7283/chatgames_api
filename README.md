# ChatGames

Inspired by the ChatGames plugin from minecraft.
It adds chat messages to the game that ask for a response, if answered correctly then they get a reward.

## Builtin Games
- **Unscramble**: Unscramble words given to gain a reward.
- **Unreverse**: Unreverse words given to gain a reward.
- **Fillout**: Fill out the words exactly to gain a reward.

## Commands
Use `/chatgame toggle` to toggle visibility of the chat-game's to you.

## Settings
Use `chatgames.new_game_interval` setting, to set (in seconds) the interval in seconds between games.
Use `chatgames.time_to_complete` setting, to set the amount of time players have to answer(in seconds).

## Technical API Examples

```lua
chatgames.register_game(game_name, answer_func)
chatgames.register_question(game_name, question, answer, is_case_sensitive) -- if is not case sensitive then both the answer and the question will be converted to lower case, and the attempt text will be converted to lowercase too before running the answer func.
chatgames.start_game(game_name)            -- At game start it says, "[CHATGAMES] You have [time_to_complete] seconds to answer the question '[question]'"
chatgames.end_game(game_name, has_winners) -- If endgame runs and there are no winners then it returns to the players chat "[CHATGAMES] Nobody got it in time, the answer was '[answer]'"

chatgames.games = {}
chatgames.active_game = {}

-- Example use case
function example_answer_func(game_name, player_name, attempt_str, time_given_in_seconds, time_used, question_id_selected)
    local question_data = chatgames.games[game_name].questions[question_id_selected]
    local answer = question_data.answer
    local player = minetest.get_player_by_name(player_name)

    if answer == attempt_str then
        local reward = calculate_reward(time_given_in_seconds, time_given_in_seconds - time_used)
        emeraldbank.add_emeralds(player, reward)
        return true
    else
        return false
    end
end

-- Example game and question registration
chatgames.register_game("Unscramble", example_answer_func)
chatgames.register_question("Unscramble", "Unscramble the text 'Lpasi Lulzai'", "Lapis Lazuli", false)
```