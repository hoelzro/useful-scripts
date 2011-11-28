DESTINATION=$(HOME)/bin
FILES=$(shell ls | grep -v Makefile | grep -v README)

install:
	mkdir -p $(DESTINATION)
	install -m755 $(FILES) $(DESTINATION)
