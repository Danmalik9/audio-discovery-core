import { Clarinet, Tx, Chain, Account, types } from "https://deno.land/x/clarinet@v1.0.0/index.ts";
import { assertEquals } from "https://deno.land/std@0.90.0/testing/asserts.ts";

Clarinet.test({
  name: "Monetization: Register free media",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const publisher = accounts.get("wallet_1")!;
    const result = chain.mineBlock([
      Tx.contractCall(
        "monetization-layer",
        "register-media",
        [
          types.uint(1),
          types.ascii("Free Content"),
          types.uint(1),
          types.uint(0),
          types.uint(0),
          types.uint(0),
        ],
        publisher.address
      ),
    ]);
    result.receipts[0].result.expectOk();
  },
});

Clarinet.test({
  name: "Monetization: Register purchase-model media",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const publisher = accounts.get("wallet_1")!;
    const result = chain.mineBlock([
      Tx.contractCall(
        "monetization-layer",
        "register-media",
        [
          types.uint(2),
          types.ascii("Premium Content"),
          types.uint(2),
          types.uint(1000000),
          types.uint(0),
          types.uint(24),
        ],
        publisher.address
      ),
    ]);
    result.receipts[0].result.expectOk();
  },
});

Clarinet.test({
  name: "Monetization: Register subscription-model media",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const publisher = accounts.get("wallet_1")!;
    const result = chain.mineBlock([
      Tx.contractCall(
        "monetization-layer",
        "register-media",
        [
          types.uint(3),
          types.ascii("Subscription Content"),
          types.uint(3),
          types.uint(500000),
          types.uint(30),
          types.uint(72),
        ],
        publisher.address
      ),
    ]);
    result.receipts[0].result.expectOk();
  },
});

Clarinet.test({
  name: "Monetization: Retrieve media details",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const publisher = accounts.get("wallet_1")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "monetization-layer",
        "register-media",
        [
          types.uint(10),
          types.ascii("Test Media"),
          types.uint(1),
          types.uint(0),
          types.uint(0),
          types.uint(0),
        ],
        publisher.address
      ),
    ]);
    
    const result = chain.callReadOnlyFn(
      "monetization-layer",
      "retrieve-media",
      [types.uint(10)],
      publisher.address
    );
    result.result.expectSome();
  },
});

Clarinet.test({
  name: "Monetization: Check fee rate",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const result = chain.callReadOnlyFn(
      "monetization-layer",
      "get-fee-rate",
      [],
      accounts.get("wallet_1")!.address
    );
    result.result.expectUint(250);
  },
});

Clarinet.test({
  name: "Monetization: Prevent invalid pricing model",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const publisher = accounts.get("wallet_1")!;
    const result = chain.mineBlock([
      Tx.contractCall(
        "monetization-layer",
        "register-media",
        [
          types.uint(99),
          types.ascii("Bad Model"),
          types.uint(99),
          types.uint(1000),
          types.uint(0),
          types.uint(0),
        ],
        publisher.address
      ),
    ]);
    result.receipts[0].result.expectErr();
  },
});

Clarinet.test({
  name: "Monetization: Prevent zero price for paid content",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const publisher = accounts.get("wallet_1")!;
    const result = chain.mineBlock([
      Tx.contractCall(
        "monetization-layer",
        "register-media",
        [
          types.uint(1),
          types.ascii("No Price"),
          types.uint(2),
          types.uint(0),
          types.uint(0),
          types.uint(0),
        ],
        publisher.address
      ),
    ]);
    result.receipts[0].result.expectErr();
  },
});

Clarinet.test({
  name: "Monetization: Update media configuration",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const publisher = accounts.get("wallet_1")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "monetization-layer",
        "register-media",
        [
          types.uint(5),
          types.ascii("Original"),
          types.uint(2),
          types.uint(1000000),
          types.uint(0),
          types.uint(24),
        ],
        publisher.address
      ),
    ]);
    
    const result = chain.mineBlock([
      Tx.contractCall(
        "monetization-layer",
        "reconfigure-media",
        [
          types.uint(5),
          types.ascii("Updated"),
          types.uint(2),
          types.uint(2000000),
          types.uint(0),
          types.uint(48),
        ],
        publisher.address
      ),
    ]);
    result.receipts[0].result.expectOk();
  },
});

Clarinet.test({
  name: "Monetization: Non-publisher cannot update media",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const publisher = accounts.get("wallet_1")!;
    const other = accounts.get("wallet_2")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "monetization-layer",
        "register-media",
        [
          types.uint(6),
          types.ascii("Original"),
          types.uint(2),
          types.uint(1000000),
          types.uint(0),
          types.uint(24),
        ],
        publisher.address
      ),
    ]);
    
    const result = chain.mineBlock([
      Tx.contractCall(
        "monetization-layer",
        "reconfigure-media",
        [
          types.uint(6),
          types.ascii("Hacked"),
          types.uint(2),
          types.uint(100),
          types.uint(0),
          types.uint(1),
        ],
        other.address
      ),
    ]);
    result.receipts[0].result.expectErr();
  },
});

Clarinet.test({
  name: "Monetization: Execute one-time purchase",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const publisher = accounts.get("wallet_1")!;
    const buyer = accounts.get("wallet_2")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "monetization-layer",
        "register-media",
        [
          types.uint(20),
          types.ascii("Purchasable"),
          types.uint(2),
          types.uint(1000000),
          types.uint(0),
          types.uint(24),
        ],
        publisher.address
      ),
    ]);
    
    const result = chain.mineBlock([
      Tx.contractCall(
        "monetization-layer",
        "acquire-media",
        [types.uint(20)],
        buyer.address
      ),
    ]);
    result.receipts[0].result.expectOk();
  },
});

Clarinet.test({
  name: "Monetization: Prevent duplicate purchases",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const publisher = accounts.get("wallet_1")!;
    const buyer = accounts.get("wallet_2")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "monetization-layer",
        "register-media",
        [
          types.uint(21),
          types.ascii("Purchasable"),
          types.uint(2),
          types.uint(1000000),
          types.uint(0),
          types.uint(24),
        ],
        publisher.address
      ),
    ]);
    
    chain.mineBlock([
      Tx.contractCall(
        "monetization-layer",
        "acquire-media",
        [types.uint(21)],
        buyer.address
      ),
    ]);
    
    const result = chain.mineBlock([
      Tx.contractCall(
        "monetization-layer",
        "acquire-media",
        [types.uint(21)],
        buyer.address
      ),
    ]);
    result.receipts[0].result.expectErr();
  },
});

Clarinet.test({
  name: "Monetization: Start subscription",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const publisher = accounts.get("wallet_1")!;
    const subscriber = accounts.get("wallet_2")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "monetization-layer",
        "register-media",
        [
          types.uint(30),
          types.ascii("Subscription"),
          types.uint(3),
          types.uint(500000),
          types.uint(30),
          types.uint(72),
        ],
        publisher.address
      ),
    ]);
    
    const result = chain.mineBlock([
      Tx.contractCall(
        "monetization-layer",
        "begin-subscription",
        [types.uint(30), types.bool(true)],
        subscriber.address
      ),
    ]);
    result.receipts[0].result.expectOk();
  },
});

Clarinet.test({
  name: "Monetization: Renew subscription",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const publisher = accounts.get("wallet_1")!;
    const subscriber = accounts.get("wallet_2")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "monetization-layer",
        "register-media",
        [
          types.uint(31),
          types.ascii("Subscription"),
          types.uint(3),
          types.uint(500000),
          types.uint(30),
          types.uint(72),
        ],
        publisher.address
      ),
    ]);
    
    chain.mineBlock([
      Tx.contractCall(
        "monetization-layer",
        "begin-subscription",
        [types.uint(31), types.bool(true)],
        subscriber.address
      ),
    ]);
    
    const result = chain.mineBlock([
      Tx.contractCall(
        "monetization-layer",
        "extend-subscription",
        [types.uint(31)],
        subscriber.address
      ),
    ]);
    result.receipts[0].result.expectOk();
  },
});

Clarinet.test({
  name: "Monetization: Cancel auto-renewal",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const publisher = accounts.get("wallet_1")!;
    const subscriber = accounts.get("wallet_2")!;
    
    chain.mineBlock([
      Tx.contractCall(
        "monetization-layer",
        "register-media",
        [
          types.uint(32),
          types.ascii("Subscription"),
          types.uint(3),
          types.uint(500000),
          types.uint(30),
          types.uint(72),
        ],
        publisher.address
      ),
    ]);
    
    chain.mineBlock([
      Tx.contractCall(
        "monetization-layer",
        "begin-subscription",
        [types.uint(32), types.bool(true)],
        subscriber.address
      ),
    ]);
    
    const result = chain.mineBlock([
      Tx.contractCall(
        "monetization-layer",
        "halt-auto-renewal",
        [types.uint(32)],
        subscriber.address
      ),
    ]);
    result.receipts[0].result.expectOk();
  },
});