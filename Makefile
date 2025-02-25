#
# prerequisites:
# - 64tass
# - hexdump

ROMS=\
	ROM/krusader.6502.bin \
	ROM/krusader.65C02.bin \

all: $(ROMS)


clean:
	$(RM) ROM/*.bin ROM/*.map ROM/*.hex ROM/*.upload ROM/*.lst ROM/*.lbl ROM/*.def ROM/*.h

ROM/krusader.%.bin: krusader.%.asm
	64tass -q -i -b $< -o $@ -L ROM/krusader.$*.lst --vice-labels -l ROM/krusader.$*.lbl --simple-labels -l ROM/krusader.$*.def --map=ROM/krusader.$*.map
	printf "#ifndef krusader_$*_h\n#define krusader_$*_h\n\n" > ROM/krusader.$*.h
	sed -e 's/= \$$/0x/' -e 's/^/#define KRUSADER_$*_SYM_/' ROM/krusader.$*.def >> ROM/krusader.$*.h
	printf "\n#endif /* krusader_$*_h */\n" >> ROM/krusader.$*.h
	cat ROM/apple-basic.rom $@ > ROM/$*.rom.bin
	hexdump -v -e '"%04_ax:" 16/1 " %02x" "\n"' ROM/$*.rom.bin | tr a-z A-Z | sed -e 's/^0/E/' -e 's/^1/F/' > ROM/$*.rom.hex
	sed -e 's/^E/A/' -e 's/^F/B/' ROM/$*.rom.hex > ROM/$*.rom.hex.upload
