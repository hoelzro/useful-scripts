package main

import (
	"bufio"
	"fmt"
	"os"
	"regexp"
	"strings"
)

var highlightColors []string = []string{
	"\x1b[43;30m", // black on yellow
	"\x1b[46;30m", // black on cyan
	"\x1b[45;30m", // black on magenta
	"\x1b[33m",    // yellow
	"\x1b[36m",    // cyan
	"\x1b[35m",    // magenta
}

func createHighlightRegexp(tokens []string) (*regexp.Regexp, error) {
	reGroups := make([]string, 0, len(tokens))
	for _, t := range tokens {
		reGroups = append(reGroups, "("+t+")") // XXX escape regexp characters?
		// XXX if not, what if a "token" defines a capture group?
	}

	re, err := regexp.Compile(strings.Join(reGroups, "|"))
	if err != nil {
		return nil, fmt.Errorf("unable to compile regexp: %w", err)
	}

	return re, nil
}

// XXX respecting existing highlights would be nice
// XXX what if two tokens' matches overlap?
func applyHighlights(line string, re *regexp.Regexp) string {
	resetColor := "\x1b[0m"

	indexes := re.FindAllStringSubmatchIndex(line, -1)

	newLineChunks := make([]string, 0)
	previousMatchEnd := 0

	for _, matchIndexes := range indexes {
		matchingGroupNum := 0
		for i := 2; i < len(matchIndexes); i += 2 {
			if matchIndexes[0] == matchIndexes[i] && matchIndexes[1] == matchIndexes[i+1] {
				matchingGroupNum = i / 2
				break
			}
		}

		if matchingGroupNum == 0 {
			panic("ah fuck")
		}

		start := matchIndexes[0]
		end := matchIndexes[1]

		if start > previousMatchEnd {
			newLineChunks = append(newLineChunks, line[previousMatchEnd:start])
		}

		colorPrefix := highlightColors[(matchingGroupNum-1)%len(highlightColors)]
		newLineChunks = append(newLineChunks, colorPrefix+line[start:end]+resetColor)

		previousMatchEnd = end
	}

	if previousMatchEnd < len(line) {
		newLineChunks = append(newLineChunks, line[previousMatchEnd:])
	}

	return strings.Join(newLineChunks, "")
}

func main() {
	highlightRE, err := createHighlightRegexp(os.Args[1:])
	if err != nil {
		fmt.Fprintf(os.Stderr, "unable to create regexp from CLI arguments: %v\n", err)
		os.Exit(1)
	}

	lines := bufio.NewScanner(os.Stdin)

	for lines.Scan() {
		line := lines.Text()
		fmt.Println(applyHighlights(line, highlightRE))
	}

	if err := lines.Err(); err != nil {
		fmt.Fprintf(os.Stderr, "unable to scan standard input: %v\n", err)
		os.Exit(1)
	}
}

// XXX invariant: a rendered line with its highlighting stripped should equal the original line (perhaps barring existing highlights)
