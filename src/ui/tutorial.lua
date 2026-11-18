-- ui/tutorial.lua  (Global script)
-- "How to play" (user, 11-17): a "?" button at the top right for everyone opens a few pages on easy play, click to
-- play and the rest of the on-screen help, each with a screenshot. Each player pages through their own copy.
-- Screenshots: assets/tutorial/<image>.png in the repository (ui/settings.lua uiAssets loads them). A page whose
-- image is nil shows text only.

TUTORIAL_PAGES = {
    { title = "Easy play", image = "easy_play",
      text = "Turn on Easy play at the bottom right. Play a card onto your play zone and the marbles you can move with it "
          .. "glow. Click one, then click the glowing spot where it goes; it moves by itself. Click a picked marble again "
          .. "to un-pick it, or press Cancel to move by hand. A 7 is two picks of a marble and a spot; a Joker is the "
          .. "marble to move, then the marble to land on. If there's only one possible move it plays by itself, and "
          .. "your turn ends by itself afterwards." },
    { title = "Click to play", image = "click_to_play",
      text = "Turn on Click to play at the bottom right. Then a quick click on a card in your hand flies it onto your "
          .. "play zone. Dragging still works, and dragging along your hand rearranges it. Click and hold (while you "
          .. "think) puts the card back. It only works on your own turn, for your first card." },
    { title = "Distances and turns", image = "hover_numbers",
      text = "Hover over any marble to see the numbers 1-13 along its route, and a red 8 where an 8 played backwards "
          .. "would take it. Near its finish, light-blue numbers show where it lands if it runs past the entrance. "
          .. "When it's your turn the screen edge glows in your colour; play your card, move, then click END TURN "
          .. "(easy play ends it for you)." },
}
TUTORIAL = TUTORIAL or {}            -- [player colour] = page number while open
-- true once the screenshots are in assets/tutorial/ on GitHub (until then the pages are text only)
TUTORIAL_HAVE_IMAGES = false

function tutorialButtonXml()
    return '<Button id="tutorialBtn" onClick="tutorialToggle" rectAlignment="UpperRight" offsetXY="-78 -64" width="54" height="54" '
        .. 'fontSize="30" fontStyle="Bold" textColor="#FFFFFF" color="#000000B0" tooltip="How to play" tooltipPosition="Left">?</Button>'
end

function tutorialXml()
    local x = {}
    for color, n in pairs(TUTORIAL) do
        local page = TUTORIAL_PAGES[n]
        local image = TUTORIAL_HAVE_IMAGES and page and page.image
        if page then
            x[#x + 1] = string.format('<Panel id="tut_%s" visibility="%s" width="760" height="%d" color="#000000E8" padding="18 18 14 14">'
                .. '<VerticalLayout spacing="10" childForceExpandHeight="false">'
                .. '<Text fontSize="28" fontStyle="Bold" color="#FFE066" preferredHeight="40">%s  (%d / %d)</Text>',
                color, color, image and 640 or 300, xmlEscape(page.title), n, #TUTORIAL_PAGES)
            if image then
                x[#x + 1] = string.format('<Image image="tut_%s" preserveAspect="true" preferredHeight="340"/>', image)
            end
            x[#x + 1] = string.format('<Text fontSize="17" color="#FFFFFF" preferredHeight="150" alignment="UpperLeft">%s</Text>', xmlEscape(page.text))
            x[#x + 1] = string.format('<HorizontalLayout spacing="10" preferredHeight="40">'
                .. '<Button id="tutPrev_%s" onClick="tutorialPage" fontSize="17">Back</Button>'
                .. '<Button id="tutNext_%s" onClick="tutorialPage" fontSize="17">Next</Button>'
                .. '<Button id="tutClose_%s" onClick="tutorialPage" fontSize="17">Close</Button></HorizontalLayout>',
                color, color, color)
            x[#x + 1] = '</VerticalLayout></Panel>'
        end
    end
    return table.concat(x)
end

function tutorialToggle(player)
    if not (player and player.color) then return end
    TUTORIAL[player.color] = (not TUTORIAL[player.color]) and 1 or nil
    refreshGameUI()
end

function tutorialPage(player, value, id)
    local what, c = tostring(id or ""):match("^tut(%a+)_(%a+)$")
    if not c or not player or player.color ~= c or not TUTORIAL[c] then return end
    if what == "Close" then TUTORIAL[c] = nil
    elseif what == "Next" then TUTORIAL[c] = TUTORIAL[c] % #TUTORIAL_PAGES + 1
    elseif what == "Prev" then TUTORIAL[c] = (TUTORIAL[c] - 2) % #TUTORIAL_PAGES + 1 end
    refreshGameUI()
end
