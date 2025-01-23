# Protocol Coverage Contract

A Clarity smart contract providing coverage protection for blockchain protocols against potential losses or vulnerabilities.

## Features

- Protocol Coverage Purchase
- Coverage Request Management
- Automated Request Processing
- Expiration Handling
- Reserve Pool Management

## Contract Functions

### Core Functions

- `acquire-coverage`: Purchase coverage protection
- `submit-request`: Submit a coverage request
- `approve-request`: Process and approve coverage requests
- `decline-request`: Decline coverage requests
- `check-and-expire-request`: Handle expired requests

### Administrative Functions

- `update-admin`: Change contract administrator
- `get-reserve-balance`: View current reserve pool balance

### Query Functions

- `is-covered`: Check if a protocol has coverage
- `get-covered-amount`: Get coverage amount for a protocol
- `get-request-status`: Check status of coverage requests

## Error Codes

- u100: Invalid value
- u101: Insufficient balance
- u102: Request not found
- u103: Not permitted
- u104: Already covered
- u105: Invalid user
- u106: Not covered
- u107: Zero value
- u108: Request processed
- u109: Reserve empty
- u110: Request not expired
- u111: Request exceeds coverage

## Usage

1. Deploy contract
2. Protocols acquire coverage by calling `acquire-coverage`
3. Submit coverage requests using `submit-request`
4. Admin approves/declines requests
5. Automatic expiration after REQUEST_EXPIRATION_PERIOD blocks

## Security

- Principal validation
- Balance checks
- Expiration periods
- Admin-only functions
- Request state validation

## Events

- coverage-acquired
- request-submitted
- request-approved
- request-declined
- request-expired
- admin-updated