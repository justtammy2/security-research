**Pattern:** When an oracle version is expired, the code should return valid = false, but instead returns valid = true, which keeps orders open that should have been invalidated.

**Sniff test:** When I see a validity flag derived from price == 0 (or any sentinel value), I ask: is there any code path that writes a non-zero fallback price in the case the flag is meant to catch? If yes, the flag is defeated, the check is a lie.

**Code shape:**

_Validity flag depends on `price == 0`, but fallback path writes a non-zero previous price → flag never fires for expired versions._

```solidity
// Validity check (in one function)
oracleVersion.valid = !oracleVersion.price.isZero();

// Fallback write (in another function)
_prices[version.timestamp] = _prices[_global.latestVersion]; // writes previous non-zero price
```

## Instances

- **Perennial V2 Update #2 — H-2** (Sherlock, Apr 2024)
- Solodit link: https://solodit.cyfrin.io/issues/h-2-requested-oracle-versions-which-have-expired-must-return-this-oracle-version-as-invalid-but-they-return-it-as-a-normal-version-with-previous-versions-price-instead-sherlock-perennial-v2-update-2-git
- GitHub source link: https://github.com/sherlock-audit/2024-02-perennial-v2-3-judging/issues/6
