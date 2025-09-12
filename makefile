# Makefile for building fibdispatch and creating symlinks

CC = gcc
CFLAGS = -Wall -O2
TARGET = fibdispatch
LINKS = fib rfib ifib

.PHONY: all clean

all: $(TARGET) $(LINKS)

$(TARGET): fibdispatch.c
	$(CC) $(CFLAGS) -o $(TARGET) fibdispatch.c

$(LINKS): $(TARGET)
	@for link in $(LINKS); do \
		if [ -e $$link ] || [ -L $$link ]; then \
			rm -f $$link; \
		fi; \
		ln -s $(TARGET) $$link; \
	done

clean:
	rm -f $(TARGET) $(LINKS)
