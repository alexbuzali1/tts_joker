--#include "constants.lua"
--#include "board.lua"
--#include "cards.lua"
--#include "discard_piles.lua"
--#include "helpers.lua"
--#include "buttons.lua"
--#include "marbles.lua"
--#include "color_picker.lua"
--#include "hover_numbers.lua"

function preGameSetup(num_players)

    printToAll("Loading " .. num_players .. " player game")

    --Change table and mat
    local new_mat = changeMatShape(MAT_SHAPES[num_players])
    Global.setVar("num_players",num_players)
    Global.call("setTableShape",{shape=TABLE_SHAPES[num_players]})

    --Create start game button
    start_game_chip =  getObjectFromGUID(START_GAME_BUTTON_GUID)
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
    
    --Label and shuffle cards
    labelDeck()
    Wait.time(function()
        deck = findCenterDeck()
    end,1)
    
    Wait.time(function()
        deck.shuffle()
    end,2)

    --Destroy player number buttons
    destroyPlayerButtons()

    --Display color picker
    for _, player in ipairs(Player.getPlayers()) do
        showColorGridForPlayer(player.color)
    end
end

function startGame(num_players)

    printToAll('Starting game')

    --Remove marble color picker
    for _, player in ipairs(Player.getPlayers()) do
        UI.hide("colorPanel_" .. player.color)
        UI.hide("colorText_" .. player.color)
    end

    --Destroy start game button
    destroyObject(getObjectFromGUID(START_GAME_BUTTON_GUID))    
    
    --Deal cards
    local deck = findCenterDeck()
    dealCardsToAllPlayers(deck,6)
    
    --Create discard piles
    local discard_piles = createDiscardPiles(num_players)
    Global.setTable("discard_piles",discard_piles)
    discard_pile_positions = {}
    for _, discard_pile in pairs(discard_piles) do
        table.insert(discard_pile_positions, discard_pile.getPosition())
    end

    --Set up reshuffle button
    local reshuffle_chip = getObjectFromGUID(RESHUFFLE_BUTTON_GUID)
    Global.setTable("discard_pile_positions", discard_pile_positions)
    reshuffleButtonSetup(reshuffle_chip,"reshuffle","Reshuffle","Reshuffle Button") 

    --Set up turn button
    local turn_chip = getObjectFromGUID(TURN_BUTTON_GUID)
    turnPlayerButtonSetup(turn_chip,"noop","","Turn Button")

    --Set up turn system
    Turns.enable = true
    Turns.pass_turns = true
    Turns.type = 1
    Turns.disable_interactations = false

    local players = Player.getPlayers()
    local random_index = math.random(#players)
    local chosen_player = players[random_index]
    Turns.turn_color = chosen_player.color
end