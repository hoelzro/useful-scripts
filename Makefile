DESTINATION=$(HOME)/bin
FILES=$(shell ls | grep -v Makefile)

install:
	mkdir -p $(DESTINATION)
	install -m755 $(FILES) $(DESTINATION)
