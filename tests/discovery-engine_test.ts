import { Clarinet, Tx, Chain, Account, types } from "https://deno.land/x/clarinet@v1.0.0/index.ts";
import { assertEquals } from "https://deno.land/std@0.90.0/testing/asserts.ts";

Clarinet.test({
  name: "Discovery: User can store a new entry",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get("wallet_1")!;
    const res = chain.mineBlock([
      Tx.contractCall(
        "discovery-engine",
        "store-new-entry",
        [
          types.utf8("Test Title"),
          types.utf8("Test Description"),
          types.utf8("https://example.com/audio.mp3"),
          types.int(40689247),
          types.int(-74012927),
          types.bool(true),
        ],
        wallet1.address
      ),
    ]);
    res.receipts[0].result.expectOk().expectUint(1);
  },
});

Clarinet.test({
  name: "Discovery: Sequential entry IDs are generated",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get("wallet_1")!;
    chain.mineBlock([
      Tx.contractCall(
        "discovery-engine",
        "store-new-entry",
        [
          types.utf8("First"),
          types.utf8("First Desc"),
          types.utf8("url1"),
          types.int(100),
          types.int(200),
          types.bool(true),
        ],
        wallet1.address
      ),
    ]);
    const block2 = chain.mineBlock([
      Tx.contractCall(
        "discovery-engine",
        "store-new-entry",
        [
          types.utf8("Second"),
          types.utf8("Second Desc"),
          types.utf8("url2"),
          types.int(150),
          types.int(250),
          types.bool(false),
        ],
        wallet1.address
      ),
    ]);
    block2.receipts[0].result.expectOk().expectUint(2);
  },
});

Clarinet.test({
  name: "Discovery: Retrieve entry details by ID",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get("wallet_1")!;
    chain.mineBlock([
      Tx.contractCall(
        "discovery-engine",
        "store-new-entry",
        [
          types.utf8("My Entry"),
          types.utf8("Description text"),
          types.utf8("audio.mp3"),
          types.int(123456),
          types.int(-654321),
          types.bool(true),
        ],
        wallet1.address
      ),
    ]);
    const result = chain.callReadOnlyFn(
      "discovery-engine",
      "fetch-entry-details",
      [types.uint(1)],
      wallet1.address
    );
    result.result.expectSome();
  },
});

Clarinet.test({
  name: "Discovery: List creator's entries",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get("wallet_1")!;
    chain.mineBlock([
      Tx.contractCall(
        "discovery-engine",
        "store-new-entry",
        [
          types.utf8("Entry 1"),
          types.utf8("Desc 1"),
          types.utf8("url1"),
          types.int(1),
          types.int(2),
          types.bool(true),
        ],
        wallet1.address
      ),
    ]);
    chain.mineBlock([
      Tx.contractCall(
        "discovery-engine",
        "store-new-entry",
        [
          types.utf8("Entry 2"),
          types.utf8("Desc 2"),
          types.utf8("url2"),
          types.int(3),
          types.int(4),
          types.bool(false),
        ],
        wallet1.address
      ),
    ]);
    const result = chain.callReadOnlyFn(
      "discovery-engine",
      "list-creator-entries",
      [types.principal(wallet1.address)],
      wallet1.address
    );
    result.result.expectOk();
  },
});

Clarinet.test({
  name: "Discovery: Only owner can modify entry",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get("wallet_1")!;
    const wallet2 = accounts.get("wallet_2")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "discovery-engine",
        "store-new-entry",
        [
          types.utf8("Original"),
          types.utf8("Desc"),
          types.utf8("url"),
          types.int(100),
          types.int(200),
          types.bool(true),
        ],
        wallet1.address
      ),
    ]);
    
    const res = chain.mineBlock([
      Tx.contractCall(
        "discovery-engine",
        "modify-entry",
        [
          types.uint(1),
          types.utf8("Modified"),
          types.utf8("New Desc"),
          types.utf8("newurl"),
          types.int(150),
          types.int(250),
          types.bool(false),
        ],
        wallet2.address
      ),
    ]);
    res.receipts[0].result.expectErr();
  },
});

Clarinet.test({
  name: "Discovery: Owner can modify entry",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get("wallet_1")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "discovery-engine",
        "store-new-entry",
        [
          types.utf8("Original"),
          types.utf8("Desc"),
          types.utf8("url"),
          types.int(100),
          types.int(200),
          types.bool(true),
        ],
        wallet1.address
      ),
    ]);
    
    const res = chain.mineBlock([
      Tx.contractCall(
        "discovery-engine",
        "modify-entry",
        [
          types.uint(1),
          types.utf8("Modified"),
          types.utf8("New Desc"),
          types.utf8("newurl"),
          types.int(150),
          types.int(250),
          types.bool(false),
        ],
        wallet1.address
      ),
    ]);
    res.receipts[0].result.expectOk();
  },
});

Clarinet.test({
  name: "Discovery: Grant access permission to principal",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get("wallet_1")!;
    const wallet2 = accounts.get("wallet_2")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "discovery-engine",
        "store-new-entry",
        [
          types.utf8("Private Entry"),
          types.utf8("Desc"),
          types.utf8("url"),
          types.int(100),
          types.int(200),
          types.bool(false),
        ],
        wallet1.address
      ),
    ]);
    
    const res = chain.mineBlock([
      Tx.contractCall(
        "discovery-engine",
        "permit-access",
        [types.uint(1), types.principal(wallet2.address)],
        wallet1.address
      ),
    ]);
    res.receipts[0].result.expectOk();
  },
});

Clarinet.test({
  name: "Discovery: Verify access permissions correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get("wallet_1")!;
    const wallet2 = accounts.get("wallet_2")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "discovery-engine",
        "store-new-entry",
        [
          types.utf8("Entry"),
          types.utf8("Desc"),
          types.utf8("url"),
          types.int(100),
          types.int(200),
          types.bool(true),
        ],
        wallet1.address
      ),
    ]);
    
    const result = chain.callReadOnlyFn(
      "discovery-engine",
      "verify-access",
      [types.uint(1), types.principal(wallet2.address)],
      wallet1.address
    );
    result.result.expectOk().expectBool(true);
  },
});

Clarinet.test({
  name: "Discovery: Public entry accessible to all",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get("wallet_1")!;
    const wallet2 = accounts.get("wallet_2")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "discovery-engine",
        "store-new-entry",
        [
          types.utf8("Public"),
          types.utf8("Desc"),
          types.utf8("url"),
          types.int(100),
          types.int(200),
          types.bool(true),
        ],
        wallet1.address
      ),
    ]);
    
    const result = chain.callReadOnlyFn(
      "discovery-engine",
      "verify-access",
      [types.uint(1), types.principal(wallet2.address)],
      wallet1.address
    );
    result.result.expectOk().expectBool(true);
  },
});

Clarinet.test({
  name: "Discovery: Private entry not accessible without permission",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get("wallet_1")!;
    const wallet2 = accounts.get("wallet_2")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "discovery-engine",
        "store-new-entry",
        [
          types.utf8("Private"),
          types.utf8("Desc"),
          types.utf8("url"),
          types.int(100),
          types.int(200),
          types.bool(false),
        ],
        wallet1.address
      ),
    ]);
    
    const result = chain.callReadOnlyFn(
      "discovery-engine",
      "verify-access",
      [types.uint(1), types.principal(wallet2.address)],
      wallet1.address
    );
    result.result.expectOk().expectBool(false);
  },
});