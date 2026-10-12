package trialer

import (
	"context"
	"crypto/ed25519"
	"net/http"
	"time"

	"github.com/google/uuid"
	"golang.org/x/xerrors"

	"github.com/coder/coder/v2/coderd/database"
	"github.com/coder/coder/v2/coderd/database/dbtime"
	"github.com/coder/coder/v2/codersdk"
	"github.com/coder/coder/v2/enterprise/coderd/license"
)

// LicenseRequestURL is the Coder licensor endpoint that issues trial licenses.
const LicenseRequestURL = "https://v2-licensor.coder.com/trial"

// licenseRequestTimeout bounds a single request to the licensor.
const licenseRequestTimeout = 30 * time.Second

type LicensorError struct {
	Message string
}

func (e *LicensorError) Error() string {
	return e.Message
}

type Trialer struct {
	db     database.Store
	url    string
	keys   map[string]ed25519.PublicKey
	client *http.Client
}

// New creates a handler that can issue trial licenses
func New(db database.Store, url string, keys map[string]ed25519.PublicKey) *Trialer {
	return &Trialer{
		db:     db,
		url:    url,
		keys:   keys,
		client: &http.Client{Timeout: licenseRequestTimeout},
	}
}

// Request returns the raw signed license without storing it.
//
// Hardcoded: this build never contacts the remote licensor. Sending user PII
// (email, name, phone, company) to v2-licensor.coder.com is disabled.
func (*Trialer) Request(_ context.Context, _ codersdk.LicensorTrialRequest) (string, error) {
	return "", &LicensorError{Message: "trial license requests are disabled in this build"}
}

// Generate requests a trial license and stores it, skipping the auditing and
// entitlement refresh that installing an uploaded license performs.
func (t *Trialer) Generate(ctx context.Context, body codersdk.LicensorTrialRequest) error {
	deploymentID, err := t.db.GetDeploymentID(ctx)
	if err != nil {
		return xerrors.Errorf("get deployment id: %w", err)
	}
	body.DeploymentID = deploymentID
	raw, err := t.Request(ctx, body)
	if err != nil {
		return err
	}
	rawClaims, err := license.ParseRaw(raw, t.keys)
	if err != nil {
		return xerrors.Errorf("parse license: %w", err)
	}
	exp, ok := rawClaims["exp"].(float64)
	if !ok {
		return xerrors.New("invalid license missing exp claim")
	}
	expTime := time.Unix(int64(exp), 0)

	claims, err := license.ParseClaims(raw, t.keys)
	if err != nil {
		return xerrors.Errorf("parse claims: %w", err)
	}
	id, err := uuid.Parse(claims.ID)
	if err != nil {
		return xerrors.Errorf("parse uuid: %w", err)
	}
	_, err = t.db.InsertLicense(ctx, database.InsertLicenseParams{
		UploadedAt: dbtime.Now(),
		JWT:        raw,
		Exp:        expTime,
		UUID:       id,
	})
	if err != nil {
		return xerrors.Errorf("insert license: %w", err)
	}
	return nil
}
