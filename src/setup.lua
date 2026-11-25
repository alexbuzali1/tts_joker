-- setup.lua
-- Setting the table up. Runs in the BUTTON objects' scripts (not the Global script):
--   1. a player-count button (4 / 6 / 8 Player) calls preGameSetup: table shape, board, marbles, hover numbers,
--      the deck, and the colour pickers
--   2. the Start Game button calls startGame: deal, play zones, Reshuffle and Turn buttons, bots, and the first turn
-- From here on the Global script runs the game (game/turns.lua). Calls into it go through Global.call /
-- Global.setTable, because each object script is a separate Lua environment.
--#include "constants.lua"
--#include "board.lua"
--#include "cards.lua"
--#include "discard_piles.lua"
--#include "helpers.lua"
--#include "buttons.lua"
--#include "marbles.lua"
--#include "hover_numbers.lua"

-- A table size was chosen: build the table for num_players.
function preGameSetup(num_players)

    printToAll("Loading " .. num_players .. " player game")

    --Change table and mat
    changeMatShape(MAT_SHAPES[num_players])
    Global.setVar("num_players",num_players)
    Global.call("setTableShape",{shape=TABLE_SHAPES[num_players]})

    --Create start game button
    local start_game_chip = getObjectFromGUID(START_GAME_BUTTON_GUID)
    startGameButtonSetup(start_game_chip,"startButtonFunction","Start\nGame","Start Game Button")

    --Calculate and assign snap points
    local board_points, start_points_by_player, friendly_bonk_points_by_player, non_start_points = getBoardPoints(num_players)
    Global.setSnapPoints(board_points)
    Global.setTable("non_start_points",non_start_points)

    --Spawn invisible planes for marble stability
    spawnInvisiblePlanes(num_players,board_points)

    --Create board
    local board_array = createBoard(num_players)
    local player_colors = PLAYER_COLORS[num_players]
    local boards_by_player = {}

    for i = 1,num_players do
        boards_by_player[player_colors[i]] = board_array[i]
    end
    Global.setTable("boards_by_player",boards_by_player)

    --Spawn marbles
    local marbles_by_player = spawnMarbles(num_players,start_points_by_player,friendly_bonk_points_by_player)
    Global.setTable("marbles_by_player", marbles_by_player)

    --Spawn hover_numbers
    local hover_numbers_by_player = spawnHoverNumbers(num_players)
    Global.setTable("hover_numbers_by_player",hover_numbers_by_player)

    --Label and shuffle cards (startGame shuffles again right before dealing)
    labelDeck()
    Wait.time(function()
        local deck = findCenterDeck()
        if deck then deck.shuffle() end
    end,2)

    --Destroy player number buttons
    destroyPlayerButtons()

    --Every player gets a colour picker for their marbles (ui/color_picker.lua, Global script)
    Global.call("showColorPickers")
end

-- Start Game was pressed: deal, make the play zones and buttons, hand empty seats to bots (or in-person players in
-- hybrid mode) and start the first turn.
function startGame(num_players)

    printToAll('Starting game')

    --Remove the colour pickers
    Global.call("hideColorPickers")

    --Destroy start game button
    destroyObject(getObjectFromGUID(START_GAME_BUTTON_GUID))

    --Shuffle right before dealing. labelDeck restacks every card in the middle and the shuffle 2 seconds later can
    --catch a deck that is still being rebuilt (the cards that land after it stay in order on top, and the deal takes
    --from the top: straight flushes). By now it has settled.
    local deck = findCenterDeck()
    deck.shuffle()
    deck.shuffle()
    printToAll('Deck shuffled (' .. #deck.getObjects() .. ' cards)')

    --Deal cards (all-bot mode: the bots take theirs below, the humans just watch)
    if not Global.getVar("BOT_ALL_SEATS") then dealCardsToAllPlayers(deck,6) end

    --Empty seats: bots (or in-person seats in hybrid mode) - bot/players.lua botOnGameStart
    Global.call("botOnGameStart", {num_players = num_players})

    --A new game: stats from zero, no undo history (Global resetForNewGame)
    Global.call("resetForNewGame", {num_players = num_players})

    --Create discard piles
    local discard_piles = createDiscardPiles(num_players)
    Global.setTable("discard_piles",discard_piles)
    local discard_pile_positions = {}
    for _, discard_pile in pairs(discard_piles) do
        table.insert(discard_pile_positions, discard_pile.getPosition())
    end

    --Set up reshuffle button
    local reshuffle_chip = getObjectFromGUID(RESHUFFLE_BUTTON_GUID)
    Global.setTable("discard_pile_positions", discard_pile_positions)
    reshuffleButtonSetup(reshuffle_chip,"reshuffle","Reshuffle","Reshuffle Button")

    --Set up turn button (its clicks end turns: game/turns.lua endTurnClicked)
    local turn_chip = getObjectFromGUID(TURN_BUTTON_GUID)
    turnPlayerButtonSetup(turn_chip,"endTurnClicked","","Turn Button")

    --TTS's own turn system is OFF (user, 11-18: "the turn indicator we don't use"): game/turns.lua runs the turns
    --and shows them (banner, splash, turn timer). Interactions stay on for everyone so players can hover marbles for
    --distances and sort their cards off-turn (moving marbles off-turn is blocked by the Global script instead).
    Turns.enable = false
    Turns.pass_turns = true
    Turns.type = 1
    Turns.disable_interactations = false

    --Pick who goes first and start the turn cycle (game/turns.lua)
    Global.call("startTurns", {num_players = num_players})
end
