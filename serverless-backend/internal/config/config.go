// Package config loads configuration from environment variables.
package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

// Env holds the configuration values for the application.
type Env struct {
	Region        string
	Bucket        string
	Table         string
	PresignTTL    time.Duration
	DevBypassAuth bool
}

// MustLoad reads the environment variables and returns an Env struct.
func MustLoad() Env {
	ttlSec, _ := strconv.Atoi(get("PRESIGN_TTL_SECONDS", "300"))
	devBypass := get("DEV_BYPASS_AUTH", "") == "true"
	e := Env{
		Region:        get("AWS_REGION", "us-east-1"),
		Bucket:        must("S3_BUCKET"),
		Table:         must("DDB_TABLE"),
		PresignTTL:    time.Duration(ttlSec) * time.Second,
		DevBypassAuth: devBypass,
	}
	return e
}

// get returns the value of the environment variable k or def if not set.
func get(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

// must returns the value of the environment variable k or panics if not set.
func must(k string) string {
	v := os.Getenv(k)
	if v == "" {
		panic(fmt.Errorf("missing env %s", k))
	}
	return v
}
