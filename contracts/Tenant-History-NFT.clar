(define-non-fungible-token tenant-history-nft uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-listing-not-found (err u102))
(define-constant err-insufficient-payment (err u103))
(define-constant err-already-exists (err u104))
(define-constant err-invalid-rating (err u105))
(define-constant err-not-authorized (err u106))
(define-constant err-token-not-found (err u107))
(define-constant err-dispute-not-found (err u108))
(define-constant err-dispute-closed (err u109))
(define-constant err-already-voted (err u110))
(define-constant err-insufficient-escrow (err u111))
(define-constant err-not-dispute-party (err u112))

(define-data-var token-id-nonce uint u1)
(define-data-var contract-fee uint u100000)

(define-map tenant-records
    uint
    {
        tenant: principal,
        landlord: principal,
        property-address: (string-ascii 256),
        rent-amount: uint,
        lease-start: uint,
        lease-end: uint,
        payment-history-score: uint,
        property-condition-score: uint,
        overall-rating: uint,
        created-at: uint,
        verified: bool,
    }
)

(define-map landlord-permissions
    {
        landlord: principal,
        tenant: principal,
    }
    bool
)

(define-map tenant-stats
    principal
    {
        total-records: uint,
        average-rating: uint,
        total-rent-paid: uint,
        verified-records: uint,
    }
)

(define-map property-listings
    uint
    {
        landlord: principal,
        property-address: (string-ascii 256),
        monthly-rent: uint,
        deposit: uint,
        available: bool,
        created-at: uint,
    }
)

(define-data-var listing-id-nonce uint u1)
(define-data-var dispute-id-nonce uint u1)

(define-map disputes
    uint
    {
        tenant: principal,
        landlord: principal,
        token-id: uint,
        dispute-type: (string-ascii 64),
        description: (string-ascii 512),
        tenant-evidence: (string-ascii 512),
        landlord-evidence: (string-ascii 512),
        escrow-amount: uint,
        tenant-deposited: uint,
        landlord-deposited: uint,
        votes-for-tenant: uint,
        votes-for-landlord: uint,
        total-voters: uint,
        status: uint,
        created-at: uint,
        resolved-at: uint,
    }
)

(define-map dispute-votes
    {
        dispute-id: uint,
        voter: principal,
    }
    uint
)

(define-read-only (get-last-token-id)
    (ok (- (var-get token-id-nonce) u1))
)

(define-read-only (get-token-uri (token-id uint))
    (ok none)
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? tenant-history-nft token-id))
)

(define-read-only (get-tenant-record (token-id uint))
    (map-get? tenant-records token-id)
)

(define-read-only (get-tenant-stats (tenant principal))
    (map-get? tenant-stats tenant)
)

(define-read-only (get-property-listing (listing-id uint))
    (map-get? property-listings listing-id)
)

(define-read-only (get-dispute (dispute-id uint))
    (map-get? disputes dispute-id)
)

(define-read-only (is-landlord-authorized
        (landlord principal)
        (tenant principal)
    )
    (default-to false
        (map-get? landlord-permissions {
            landlord: landlord,
            tenant: tenant,
        })
    )
)

(define-public (mint-tenant-record
        (tenant principal)
        (property-address (string-ascii 256))
        (rent-amount uint)
        (lease-start uint)
        (lease-end uint)
        (payment-score uint)
        (condition-score uint)
        (overall-rating uint)
    )
    (let (
            (token-id (var-get token-id-nonce))
            (current-block u1)
        )
        (asserts!
            (or
                (is-eq tx-sender contract-owner)
                (is-landlord-authorized tx-sender tenant)
            )
            err-not-authorized
        )
        (asserts! (and (>= payment-score u1) (<= payment-score u10))
            err-invalid-rating
        )
        (asserts! (and (>= condition-score u1) (<= condition-score u10))
            err-invalid-rating
        )
        (asserts! (and (>= overall-rating u1) (<= overall-rating u10))
            err-invalid-rating
        )

        (try! (nft-mint? tenant-history-nft token-id tenant))

        (map-set tenant-records token-id {
            tenant: tenant,
            landlord: tx-sender,
            property-address: property-address,
            rent-amount: rent-amount,
            lease-start: lease-start,
            lease-end: lease-end,
            payment-history-score: payment-score,
            property-condition-score: condition-score,
            overall-rating: overall-rating,
            created-at: current-block,
            verified: (is-eq tx-sender contract-owner),
        })

        (update-tenant-stats tenant rent-amount overall-rating
            (is-eq tx-sender contract-owner)
        )
        (var-set token-id-nonce (+ token-id u1))
        (ok token-id)
    )
)

(define-public (grant-landlord-permission (landlord principal))
    (begin
        (map-set landlord-permissions {
            landlord: landlord,
            tenant: tx-sender,
        }
            true
        )
        (ok true)
    )
)

(define-public (revoke-landlord-permission (landlord principal))
    (begin
        (map-delete landlord-permissions {
            landlord: landlord,
            tenant: tx-sender,
        })
        (ok true)
    )
)

(define-public (verify-record (token-id uint))
    (let ((record (unwrap! (map-get? tenant-records token-id) err-token-not-found)))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)

        (map-set tenant-records token-id (merge record { verified: true }))

        (let (
                (tenant (get tenant record))
                (stats (default-to {
                    total-records: u0,
                    average-rating: u0,
                    total-rent-paid: u0,
                    verified-records: u0,
                }
                    (map-get? tenant-stats tenant)
                ))
            )
            (map-set tenant-stats tenant
                (merge stats { verified-records: (+ (get verified-records stats) u1) })
            )
        )
        (ok true)
    )
)

(define-public (create-property-listing
        (property-address (string-ascii 256))
        (monthly-rent uint)
        (deposit uint)
    )
    (let (
            (listing-id (var-get listing-id-nonce))
            (current-block u1)
        )
        (map-set property-listings listing-id {
            landlord: tx-sender,
            property-address: property-address,
            monthly-rent: monthly-rent,
            deposit: deposit,
            available: true,
            created-at: current-block,
        })
        (var-set listing-id-nonce (+ listing-id u1))
        (ok listing-id)
    )
)

(define-public (update-listing-availability
        (listing-id uint)
        (available bool)
    )
    (let ((listing (unwrap! (map-get? property-listings listing-id) err-listing-not-found)))
        (asserts! (is-eq tx-sender (get landlord listing)) err-not-authorized)

        (map-set property-listings listing-id
            (merge listing { available: available })
        )
        (ok true)
    )
)

(define-public (pay-application-fee (listing-id uint))
    (let (
            (listing (unwrap! (map-get? property-listings listing-id)
                err-listing-not-found
            ))
            (fee (var-get contract-fee))
        )
        (asserts! (get available listing) err-listing-not-found)

        (try! (stx-transfer? fee tx-sender contract-owner))
        (ok true)
    )
)

(define-public (transfer
        (token-id uint)
        (sender principal)
        (recipient principal)
    )
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (try! (nft-transfer? tenant-history-nft token-id sender recipient))
        (ok true)
    )
)

(define-public (set-contract-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set contract-fee new-fee)
        (ok true)
    )
)

(define-private (update-tenant-stats
        (tenant principal)
        (rent uint)
        (rating uint)
        (verified bool)
    )
    (let (
            (current-stats (default-to {
                total-records: u0,
                average-rating: u0,
                total-rent-paid: u0,
                verified-records: u0,
            }
                (map-get? tenant-stats tenant)
            ))
            (new-total-records (+ (get total-records current-stats) u1))
            (new-total-rent (+ (get total-rent-paid current-stats) rent))
            (new-verified (if verified
                (+ (get verified-records current-stats) u1)
                (get verified-records current-stats)
            ))
            (current-avg (get average-rating current-stats))
            (new-avg (if (is-eq (get total-records current-stats) u0)
                rating
                (/ (+ (* current-avg (get total-records current-stats)) rating)
                    new-total-records
                )
            ))
        )
        (map-set tenant-stats tenant {
            total-records: new-total-records,
            average-rating: new-avg,
            total-rent-paid: new-total-rent,
            verified-records: new-verified,
        })
    )
)

(define-read-only (get-tenant-reputation-score (tenant principal))
    (let (
            (stats (unwrap! (map-get? tenant-stats tenant) (ok u0)))
            (verified-ratio (if (> (get total-records stats) u0)
                (/ (* (get verified-records stats) u100)
                    (get total-records stats)
                )
                u0
            ))
            (rating-score (* (get average-rating stats) u10))
            (volume-bonus (if (> (get total-records stats) u5)
                u50
                u0
            ))
        )
        (ok (+ rating-score verified-ratio volume-bonus))
    )
)

(define-read-only (search-available-listings (max-rent uint))
    (ok "Use off-chain indexing for complex queries")
)

(define-public (bulk-verify-records (token-ids (list 10 uint)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map verify-single-record token-ids))
    )
)

(define-private (verify-single-record (token-id uint))
    (match (map-get? tenant-records token-id)
        record (map-set tenant-records token-id (merge record { verified: true }))
        false
    )
)

(define-read-only (get-contract-stats)
    (ok {
        total-tokens: (- (var-get token-id-nonce) u1),
        total-listings: (- (var-get listing-id-nonce) u1),
        contract-fee: (var-get contract-fee),
        owner: contract-owner,
    })
)

(define-public (create-dispute
        (token-id uint)
        (dispute-type (string-ascii 64))
        (description (string-ascii 512))
        (escrow-amount uint)
    )
    (let (
            (record (unwrap! (map-get? tenant-records token-id) err-token-not-found))
            (dispute-id (var-get dispute-id-nonce))
            (tenant-principal (get tenant record))
            (landlord-principal (get landlord record))
        )
        (asserts!
            (or
                (is-eq tx-sender tenant-principal)
                (is-eq tx-sender landlord-principal)
            )
            err-not-dispute-party
        )
        (asserts! (> escrow-amount u0) err-insufficient-escrow)

        (map-set disputes dispute-id {
            tenant: tenant-principal,
            landlord: landlord-principal,
            token-id: token-id,
            dispute-type: dispute-type,
            description: description,
            tenant-evidence: "",
            landlord-evidence: "",
            escrow-amount: escrow-amount,
            tenant-deposited: u0,
            landlord-deposited: u0,
            votes-for-tenant: u0,
            votes-for-landlord: u0,
            total-voters: u0,
            status: u1,
            created-at: stacks-block-height,
            resolved-at: u0,
        })

        (var-set dispute-id-nonce (+ dispute-id u1))
        (ok dispute-id)
    )
)

(define-public (deposit-escrow (dispute-id uint))
    (let (
            (dispute (unwrap! (map-get? disputes dispute-id) err-dispute-not-found))
            (escrow-amount (get escrow-amount dispute))
            (tenant-principal (get tenant dispute))
            (landlord-principal (get landlord dispute))
        )
        (asserts! (is-eq (get status dispute) u1) err-dispute-closed)
        (asserts!
            (or
                (is-eq tx-sender tenant-principal)
                (is-eq tx-sender landlord-principal)
            )
            err-not-dispute-party
        )

        (try! (stx-transfer? escrow-amount tx-sender (as-contract tx-sender)))

        (if (is-eq tx-sender tenant-principal)
            (map-set disputes dispute-id
                (merge dispute { tenant-deposited: escrow-amount })
            )
            (map-set disputes dispute-id
                (merge dispute { landlord-deposited: escrow-amount })
            )
        )

        (let ((updated-dispute (unwrap! (map-get? disputes dispute-id) err-dispute-not-found)))
            (if (and
                    (> (get tenant-deposited updated-dispute) u0)
                    (> (get landlord-deposited updated-dispute) u0)
                )
                (begin
                    (map-set disputes dispute-id
                        (merge updated-dispute { status: u2 })
                    )
                    (ok true)
                )
                (ok true)
            )
        )
    )
)

(define-public (submit-evidence
        (dispute-id uint)
        (evidence (string-ascii 512))
    )
    (let (
            (dispute (unwrap! (map-get? disputes dispute-id) err-dispute-not-found))
            (tenant-principal (get tenant dispute))
            (landlord-principal (get landlord dispute))
        )
        (asserts! (>= (get status dispute) u1) err-dispute-closed)
        (asserts!
            (or
                (is-eq tx-sender tenant-principal)
                (is-eq tx-sender landlord-principal)
            )
            err-not-dispute-party
        )

        (if (is-eq tx-sender tenant-principal)
            (map-set disputes dispute-id
                (merge dispute { tenant-evidence: evidence })
            )
            (map-set disputes dispute-id
                (merge dispute { landlord-evidence: evidence })
            )
        )
        (ok true)
    )
)

(define-public (vote-on-dispute
        (dispute-id uint)
        (vote-for-tenant bool)
    )
    (let (
            (dispute (unwrap! (map-get? disputes dispute-id) err-dispute-not-found))
            (voter-stats (map-get? tenant-stats tx-sender))
        )
        (asserts! (is-eq (get status dispute) u2) err-dispute-closed)
        (asserts! (is-some voter-stats) err-not-authorized)
        (asserts!
            (is-none (map-get? dispute-votes {
                dispute-id: dispute-id,
                voter: tx-sender,
            }))
            err-already-voted
        )

        (map-set dispute-votes {
            dispute-id: dispute-id,
            voter: tx-sender,
        }
            (if vote-for-tenant
                u1
                u2
            ))

        (let (
                (new-tenant-votes (if vote-for-tenant
                    (+ (get votes-for-tenant dispute) u1)
                    (get votes-for-tenant dispute)
                ))
                (new-landlord-votes (if vote-for-tenant
                    (get votes-for-landlord dispute)
                    (+ (get votes-for-landlord dispute) u1)
                ))
                (new-total-voters (+ (get total-voters dispute) u1))
            )
            (map-set disputes dispute-id
                (merge dispute {
                    votes-for-tenant: new-tenant-votes,
                    votes-for-landlord: new-landlord-votes,
                    total-voters: new-total-voters,
                })
            )
        )
        (ok true)
    )
)

(define-public (resolve-dispute (dispute-id uint))
    (let (
            (dispute (unwrap! (map-get? disputes dispute-id) err-dispute-not-found))
            (total-votes (get total-voters dispute))
            (tenant-votes (get votes-for-tenant dispute))
            (landlord-votes (get votes-for-landlord dispute))
            (tenant-wins (> tenant-votes landlord-votes))
            (escrow-amount (get escrow-amount dispute))
            (total-escrow (* escrow-amount u2))
            (winner (if tenant-wins
                (get tenant dispute)
                (get landlord dispute)
            ))
        )
        (asserts! (is-eq (get status dispute) u2) err-dispute-closed)
        (asserts! (>= total-votes u3) err-not-authorized)

        (try! (as-contract (stx-transfer? total-escrow tx-sender winner)))

        (map-set disputes dispute-id
            (merge dispute {
                status: u3,
                resolved-at: stacks-block-height,
            })
        )
        (ok tenant-wins)
    )
)

(define-public (emergency-pause)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok true)
    )
)
