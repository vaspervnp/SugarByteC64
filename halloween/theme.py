"""The Halloween edition's look, for tools/mkgfx64.py --theme (it replaces the
upper-case settings there). A night board: black, a dark grey grid, the
candies of tools/mkart.py, slime for the jelly, cobwebs for the icing; the
menu in pumpkin orange and witch's purple."""

BOARD_BG = 0                    # black: the night
MENU_BG = 0
OVER_FLASH = 8                  # out of moves: the border blinks orange
HUD_SEAM = 4                    # purple between the board and the HUD
SELECT_COL = 7                  # the selection: a yellow frame

# CPC pen -> C64 colour: the game's, but what was the blue of the board is
# the black of the night (the HUD's icons and glyphs sat on it)
PENS = {0: 0, 1: 1, 2: 12, 3: 0, 4: 3, 5: 2, 6: 9, 7: 8, 8: 9, 9: 7,
        10: 13, 11: 5, 12: 14, 13: 0, 14: 4, 15: 0}

SHEETS = {
    "candy": ("assets/candy_sheet.png", "assets/candy_sheet.json"),
    "cells": ("assets/cells_sheet.png", "assets/cells_sheet.json"),
}
# the colour RAM of the cells: the stars and the slime keep it under a candy
CELL_PREFER11 = {1: 4, 2: 11, 3: 5, 4: 13}

# the pops, the beams, the stars: yellow, like a candle
OVERLAY_PENS = {4: 7}
# the jelly's icon: slime green
ICON_PENS = {4: {4: 13}}

# the title's letters by hue (base, shade): pumpkin, witch, slime, blood,
# candle, bone
HUE_C64 = [(8, 9), (4, 11), (13, 5), (10, 2), (7, 8), (15, 12)]
TITLE_PENS = {5: 10, 6: 2, 7: 8, 8: 9, 9: 7, 10: 13, 11: 5, 12: 3, 13: 14, 14: 8, 15: 9, 3: 11}
# the plates: orange with a candle-yellow edge; the pointer striped orange and purple
MENU_PENS = {**TITLE_PENS, 14: 8, 15: 9, 1: 7, 3: 11, 5: 4}
# the canes down the sides: orange and purple; pumpkins in the corners
BORDER_PENS = {**TITLE_PENS, 1: 8, 5: 4, 3: 11, 6: 11, 14: 8, 15: 9}
FOOT = (8, 4, 11)               # the game's foot: orange and purple, a dark grey edge

FRAME_TEXT = ("HALLOWEEN EDITION", 4, 7)
