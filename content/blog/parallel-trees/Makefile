SVGS := $(patsubst %.dot,%.svg,$(wildcard *.dot))

all: $(SVGS)

%.svg: %.dot
	dot -Tsvg $< -o $@

clean:
	rm -f $(SVGS)

.PHONY: all clean