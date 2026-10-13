# Sugar Byte - Commodore 64 build
#   make        -> build/sugar.d64 (disk) and build/sugar.tap (tape)
#   make run    -> x64sc with autostart
#   make test   -> headless tests (VICE binary monitor)
#   make manuals -> docs/manual-en.pdf, docs/manual-el.pdf (fpdf2)
#   make screenshots -> docs/screenshots/*.png and the manual's pictures
#   make gfx    -> src/data/ from assets/cpc, levels/, music/, voice/
#                  (and build/mockup_*.png)

X64     ?= x64sc
C1541   ?= c1541
TASS    ?= 64tass
PYTHON  ?= python3

BUILD   := build
SRC     := $(wildcard src/*.asm src/*.inc)
DATA_IN := $(wildcard assets/cpc/*) levels/levels.txt $(wildcard music/*.txt) $(wildcard voice/*.wav) \
           tools/mkgfx64.py tools/c64palette.py tools/levels.py tools/mkmusic64.py tools/voice64.py
STAMP   := src/data/.stamp
PRG     := $(BUILD)/sugar.prg
D64     := $(BUILD)/sugar.d64
TAP     := $(BUILD)/sugar.tap
BOOT    := $(BUILD)/boot.prg
LABELS  := $(BUILD)/labels.txt
LIST    := $(BUILD)/sugar.lst
VOICES  := sugarbyte sweet delicious crush

# -C case-sensitive labels, -a ASCII source, -B long branches where needed,
# -Wall all warnings
TASSFLAGS := -C -a -B -Wall -I src

.PHONY: all run test gfx manuals screenshots clean

all: $(D64) $(TAP)

$(BUILD):
	mkdir -p $@

gfx: $(STAMP)

$(STAMP): $(DATA_IN)
	$(PYTHON) tools/mkgfx64.py
	$(PYTHON) tools/levels.py levels/levels.txt src/data/levels.asm
	$(PYTHON) tools/mkmusic64.py
	$(PYTHON) tools/voice64.py src/data/voice.asm $(foreach v,$(VOICES),$(v)=voice/$(v).wav)
	touch $@

$(PRG): $(SRC) $(STAMP) | $(BUILD)
	$(TASS) $(TASSFLAGS) src/main.asm -o $@ --vice-labels-numeric -l $(LABELS) -L $(LIST)

$(D64): $(PRG)
	rm -f $@
	$(C1541) -format "sugar byte,sb" d64 $@ -write $(PRG) sugar >/dev/null

# the tape: a KERNAL-format boot file with a turbo loader, then the game in turbo
$(BOOT): src/tapeboot.asm | $(BUILD)
	$(TASS) $(TASSFLAGS) $< -o $@

$(TAP): $(BOOT) $(PRG) tools/mktap.py
	$(PYTHON) tools/mktap.py $(BOOT) $(PRG) 0x$$(awk '$$3 == ".start" {print $$2}' $(LABELS)) $@

run: $(D64)
	$(X64) -autostart $(D64)

test: $(D64)
	$(PYTHON) tests/run_tests.py

MANUAL_PICS := $(wildcard docs/*.png)
manuals: docs/manual-en.pdf docs/manual-el.pdf

docs/manual-en.pdf: manual.md $(MANUAL_PICS) tools/mkmanual.py
	$(PYTHON) tools/mkmanual.py $< $@

docs/manual-el.pdf: manual.el.md $(MANUAL_PICS) tools/mkmanual.py
	$(PYTHON) tools/mkmanual.py $< $@

screenshots: $(PRG)
	$(PYTHON) tools/screenshots64.py

clean:
	rm -rf $(BUILD) src/data
