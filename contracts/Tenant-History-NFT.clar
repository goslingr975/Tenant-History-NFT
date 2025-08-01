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

(define-public (emergency-pause)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok true)
    )
)
