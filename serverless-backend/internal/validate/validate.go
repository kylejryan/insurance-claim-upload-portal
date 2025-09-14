// Package validate provides functions to validate file uploads and metadata.
package validate

import (
	"errors"
	"path/filepath"
	"regexp"
	"strings"
)

var tagRx = regexp.MustCompile(`^[a-zA-Z0-9 _\-]{1,32}$`)

// FilenameTxt checks that the filename has a .txt extension (case insensitive).
func FilenameTxt(fn string) error {
	if strings.ToLower(filepath.Ext(fn)) != ".txt" {
		return errors.New("only .txt files allowed")
	}
	return nil
}

// ContentTypeTextPlain checks that the Content-Type is exactly text/plain (case insensitive, trimmed).
func ContentTypeTextPlain(ct string) error {
	if strings.TrimSpace(strings.ToLower(ct)) != "text/plain" {
		return errors.New("Content-Type must be text/plain")
	}
	return nil
}

// TagsOK checks that there is 1 to 10 tags, each matching the allowed pattern.
func TagsOK(tags []string) error {
	if len(tags) == 0 || len(tags) > 10 {
		return errors.New("provide 1..10 tags")
	}
	for _, t := range tags {
		if !tagRx.MatchString(t) {
			return errors.New("invalid tag: " + t)
		}
	}
	return nil
}

// ClientOK checks that the client string is non-empty after trimming whitespace.
func ClientOK(c string) error {
	if strings.TrimSpace(c) == "" {
		return errors.New("client required")
	}
	return nil
}
