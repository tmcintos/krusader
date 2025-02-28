#
# prerequisites:
# - 64tass
# - cat, cut, grep, printf, sed, tr, xxd

ROMS=\
	ROM/krusader.6502.bin \
	ROM/krusader.65C02.bin \

all: $(ROMS) doc/krusader.pdf

clean:
	$(RM) ROM/*.bin ROM/*.map ROM/*.hex ROM/*.upload ROM/*.lst ROM/*.lbl ROM/*.def ROM/*.h doc/krusader.*

# Note:
# - commit updated doc/krusader.pdf separately after modifying doc/Assembler.tex to ensure reproducible build!
# - must run pdflatex twice to resolve references
doc/krusader.pdf: doc/Assembler.tex
	cd doc && export SOURCE_DATE_EPOCH=$$(git log -1 --format=%ct Assembler.tex) && \
		pdflatex -jobname=krusader Assembler.tex >krusader.err && \
		pdflatex -jobname=krusader Assembler.tex >krusader.err

ROM/krusader.%.bin: krusader.%.asm
	64tass -q -i -b $< -o $@ -L ROM/krusader.$*.lst --vice-labels -l ROM/krusader.$*.lbl --simple-labels -l ROM/krusader.$*.def --map=ROM/krusader.$*.map
	printf "#ifndef krusader_$*_h\n#define krusader_$*_h\n\n" > ROM/krusader.$*.h
	sed -e 's/= \$$/0x/' -e 's/^/#define KRUSADER_$*_SYM_/' ROM/krusader.$*.def >> ROM/krusader.$*.h
	printf "\n#endif /* krusader_$*_h */\n" >> ROM/krusader.$*.h
	if grep -q -E 'INROM\s+=\s+\$$1' ROM/krusader.$*.def; then \
		cat ROM/apple-basic.rom $@ > ROM/$*.rom.bin; \
		xxd -u -g 1 -o 0xE000 ROM/$*.rom.bin | cut -c5-57 | tr a-z A-Z > ROM/$*.rom.hex; \
		xxd -u -g 1 -o 0xA000 ROM/$*.rom.bin | cut -c5-57 | tr a-z A-Z > ROM/$*.rom.hex.upload; \
	else \
		xxd -u -g 1 -o 0x7100 $@ | cut -c5-57 | tr a-z A-Z > ROM/krusader.$*.hex; \
	fi
