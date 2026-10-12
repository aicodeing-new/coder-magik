package main

import (
	"database/sql"
	"fmt"
	"net/url"
	"os"

	_ "github.com/lib/pq"
	"golang.org/x/xerrors"
)

func main() {
	if err := run(); err != nil {
		_, _ = fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run() error {
	u, err := url.Parse(os.Getenv("CODER_PG_CONNECTION_URL"))
	if err != nil {
		return xerrors.New("invalid database connection URL")
	}
	u.Path = "/postgres"
	q := u.Query()
	q.Set("connect_timeout", "10")
	u.RawQuery = q.Encode()
	db, err := sql.Open("postgres", u.String())
	if err != nil {
		return xerrors.New("open database connection failed")
	}
	defer db.Close()
	var exists, canCreate bool
	var version string
	err = db.QueryRow(`SELECT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'coder_sso'), rolcreatedb, version() FROM pg_roles WHERE rolname = current_user`).Scan(&exists, &canCreate, &version)
	if err != nil {
		return xerrors.Errorf("inspect database: %w", err)
	}
	_, _ = fmt.Printf("coder_sso database exists: %v; role can create database: %v; server: %s\n", exists, canCreate, version)
	if exists {
		return nil
	}
	if !canCreate {
		return xerrors.New("magik role cannot create coder_sso database; administrator must create it with owner magik")
	}
	if _, err := db.Exec(`CREATE DATABASE coder_sso OWNER magik`); err != nil {
		return xerrors.Errorf("create coder_sso database: %w", err)
	}
	_, _ = fmt.Println("Created coder_sso database with owner magik")
	return nil
}
