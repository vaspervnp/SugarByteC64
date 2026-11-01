# Sugar Byte - Halloween edition (Commodore 64)
#
# The game's code is the one in ../src (copied to build/src); what this
# directory brings is its own: the look (theme.py, the pictures of
# tools/mkart.py in assets/), the music and the effects (music/), the voice
# (voice/). The levels are the game's (../levels).
#
#   make        -> build/sugar.d64 (disk) and build/sugar.tap (tape)
#   make run    -> x64sc with autostart
#   make test   -> the game's headless tests, on this edition
#   make art    -> assets/ from tools/mkart.py (and build/preview_*.png)
#   make screenshots -> docs/*.png

X64     ?= x64sc
C1541   ?= c1541
TASS    ?= 64tass
PYTHON  ?= python3

TOP     := ..
TOOLS   := $(TOP)/tools
BUILD   := build
SRC_DIR := $(BUILD)/src
DATA    := $(SRC_DIR)/data
SRC     := $(wildcard $(TOP)/src/*.asm $(TOP)/src/*.inc)
PRG     := $(BUILD)/sugar.prg
D64     := $(BUILD)/sugar.d64
TAP     := $(BUILD)/sugar.tap
BOOT    := $(BUILD)/boot.prg
LABELS  := $(BUILD)/labels.txt
LIST    := $(BUILD)/sugar.lst
VOICES  := sugarbyte sweet delicious crush
ART     := assets/candy_sheet.png assets/candy_sheet.json assets/cells_sheet.png assets/cells_sheet.json
STAMP   := $(DATA)/.stamp
DATA_IN := theme.py $(ART) $(wildcard $(TOP)/assets/cpc/*) $(TOP)/levels/levels.txt \
           $(wildcard music/*.txt) $(wildcard voice/*.wav) \
           $(TOOLS)/mkgfx64.py $(TOOLS)/c64palette.py $(TOOLS)/levels.py $(TOOLS)/mkmusic64.py $(TOOLS)/voice64.py

TASSFLAGS := -C -a -B -Wall -I $(SRC_DIR)

.PHONY: all run test art screenshots clean

all: $(D64) $(TAP)

$(SRC_DIR)/.copied: $(SRC)
	mkdir -p $(SRC_DIR)
	cp $(SRC) $(SRC_DIR)/
	touch $@

art: $(ART)

$(ART) &: tools/mkart.py
	$(PYTHON) tools/mkart.py

$(STAMP): $(DATA_IN) $(SRC_DIR)/.copied
	mkdir -p $(DATA)
	$(PYTHON) $(TOOLS)/mkgfx64.py --theme theme.py --out $(DATA) --build $(BUILD)
	$(PYTHON) $(TOOLS)/levels.py $(TOP)/levels/levels.txt $(DATA)/levels.asm
	$(PYTHON) $(TOOLS)/mkmusic64.py music $(DATA)/music.asm
	$(PYTHON) $(TOOLS)/voice64.py $(DATA)/voice.asm $(foreach v,$(VOICES),$(v)=voice/$(v).wav)
	touch $@

$(PRG): $(SRC_DIR)/.copied $(STAMP)
	$(TASS) $(TASSFLAGS) $(SRC_DIR)/main.asm -o $@ --vice-labels-numeric -l $(LABELS) -L $(LIST)

$(D64): $(PRG)
	rm -f $@
	$(C1541) -format "sugar halloween,sh" d64 $@ -write $(PRG) sugar >/dev/null

$(BOOT): $(SRC_DIR)/.copied
	$(TASS) $(TASSFLAGS) $(SRC_DIR)/tapeboot.asm -o $@

$(TAP): $(BOOT) $(PRG) $(TOOLS)/mktap.py
	$(PYTHON) $(TOOLS)/mktap.py $(BOOT) $(PRG) 0x$$(awk '$$3 == ".start" {print $$2}' $(LABELS)) $@ "SUGAR HALLOWEEN"

run: $(D64)
	$(X64) -autostart $(D64)

test: $(D64) $(TAP)
	SUGAR_BUILD=$(abspath $(BUILD)) SUGAR_MUSIC=$(abspath music) $(PYTHON) $(TOP)/tests/run_tests.py

screenshots: $(PRG)
	SUGAR_BUILD=$(abspath $(BUILD)) $(PYTHON) tools/screenshots.py

clean:
	rm -rf $(BUILD)
